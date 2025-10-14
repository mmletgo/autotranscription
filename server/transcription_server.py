#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Audio Transcription Server
Provides REST API for speech-to-text with concurrent processing and queue management
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import logging
from faster_whisper import WhisperModel
import io
import json
import os
from datetime import datetime
import threading
import queue
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import gc
from contextlib import contextmanager

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global variables
transcription_queue = queue.Queue(maxsize=100)  # 请求队列
active_transcriptions = 0  # 活跃转写计数
transcription_executor = None  # 线程池
model = None
config = None
lock = threading.Lock()


# Load configuration
def load_config():
    global config
    possible_paths = [
        os.path.join(
            os.path.dirname(os.path.dirname(__file__)), "config", "server_config.json"
        ),
        os.path.join(os.path.dirname(__file__), "config", "server_config.json"),
        "/app/config/server_config.json",
        "config/server_config.json",
    ]

    for config_path in possible_paths:
        if os.path.exists(config_path):
            with open(config_path, "r", encoding="utf-8") as f:
                config = json.load(f)
                break
    else:
        # 默认配置
        config = {
            "model_size": "base",
            "device": "cpu",
            "compute_type": "int8",
            "language": "zh",
            "initial_prompt": "The following are sentences in Mandarin.",
            "host": "0.0.0.0",
            "port": 5000,
            "network_mode": "lan",
            "workers": 4,
            "max_concurrent_transcriptions": 8,
            "queue_size": 100,
            "timeout": 600,
            "log_level": "INFO",
        }

    return config


# Initialize Whisper model
def initialize_model():
    global model
    logger.info(f"Loading Whisper model: {config['model_size']}")

    try:
        model_size = config["model_size"]
        # 优先使用Systran的Faster Whisper模型
        model = WhisperModel(
            model_size,
            device=config["device"],
            compute_type=config["compute_type"],
            local_files_only=False,
        )
        logger.info("Systran Faster Whisper model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load Systran model {config['model_size']}: {e}")
        logger.info("Falling back to base model")
        try:
            model = WhisperModel(
                "base", device=config["device"], compute_type=config["compute_type"]
            )
            logger.info("Base model loaded as fallback")
        except Exception as fallback_error:
            logger.error(f"Failed to load base model: {fallback_error}")
            raise fallback_error


# Configure CORS
def configure_cors():
    if config.get("network_mode") == "internet":
        CORS(app)
        logger.info("Network mode: Internet - CORS enabled")
    else:
        CORS(app, resources={r"/api/*": {"origins": "*"}})
        logger.info("Network mode: LAN")


# 内存管理装饰器
@contextmanager
def memory_management():
    """内存管理上下文"""
    try:
        yield
    finally:
        # 强制垃圾回收释放GPU内存
        gc.collect()
        if config["device"] == "cuda":
            import torch

            if torch.cuda.is_available():
                torch.cuda.empty_cache()


class TranscriptionService:
    """增强版音频转写服务"""

    @staticmethod
    def transcribe_audio_async(
        audio_data, language=None, initial_prompt=None, request_id=None
    ):
        """
        异步音频转写

        Args:
            audio_data: 音频数据
            language: 语言代码
            initial_prompt: 初始提示
            request_id: 请求ID

        Returns:
            dict: 转写结果
        """
        global active_transcriptions

        with memory_management():
            try:
                # 使用默认配置
                if language is None:
                    language = config.get("language")
                if initial_prompt is None:
                    initial_prompt = config.get("initial_prompt")

                logger.info(
                    f"Starting transcription (ID: {request_id}, language: {language})"
                )

                # 执行转写
                segments, info = model.transcribe(
                    audio_data,
                    task="transcribe",
                    beam_size=5,
                    language=language,
                    temperature=0.0,
                    initial_prompt=initial_prompt,
                    vad_filter=True,
                    vad_parameters=dict(min_silence_duration_ms=500),
                    condition_on_previous_text=False,
                )

                # 收集所有片段
                segment_list = []
                full_text = ""

                for segment in segments:
                    segment_data = {
                        "start": segment.start,
                        "end": segment.end,
                        "text": segment.text.strip(),
                    }
                    segment_list.append(segment_data)
                    full_text += segment.text

                result = {
                    "success": True,
                    "request_id": request_id,
                    "language": info.language,
                    "language_probability": info.language_probability,
                    "segments": segment_list,
                    "text": full_text.strip(),
                    "duration": info.duration if hasattr(info, "duration") else None,
                    "processing_time": None,  # 将在外部计算
                }

                logger.info(
                    f"Transcription completed (ID: {request_id}): {len(segment_list)} segments"
                )
                return result

            except Exception as e:
                logger.error(
                    f"Transcription failed (ID: {request_id}): {str(e)}", exc_info=True
                )
                return {"success": False, "request_id": request_id, "error": str(e)}


def process_queued_transcription():
    """处理队列中的转写请求"""
    global active_transcriptions

    while True:
        try:
            # 从队列获取请求
            task = transcription_queue.get(timeout=1)
            if task is None:  # 停止信号
                break

            request_id, audio_data, language, initial_prompt, future = task

            with lock:
                active_transcriptions += 1

            try:
                # 执行转写
                start_time = time.time()
                result = TranscriptionService.transcribe_audio_async(
                    audio_data, language, initial_prompt, request_id
                )
                result["processing_time"] = time.time() - start_time

                # 设置结果
                future.set_result(result)

            except Exception as e:
                future.set_exception(e)
            finally:
                with lock:
                    active_transcriptions -= 1

                transcription_queue.task_done()

        except queue.Empty:
            continue
        except Exception as e:
            logger.error(f"Error processing queued transcription: {e}")


def start_transcription_workers():
    """启动转写工作线程"""
    global transcription_executor
    max_workers = config.get("max_concurrent_transcriptions", 8)

    transcription_executor = ThreadPoolExecutor(
        max_workers=max_workers, thread_name_prefix="transcription"
    )

    # 启动多个工作线程
    for i in range(max_workers):
        worker = threading.Thread(
            target=process_queued_transcription, name=f"TranscriptionWorker-{i}"
        )
        worker.daemon = True
        worker.start()

    logger.info(f"Started {max_workers} transcription workers")


# API Routes


@app.route("/api/health", methods=["GET"])
def health_check():
    """健康检查端点"""
    return jsonify(
        {
            "status": "healthy",
            "model": config["model_size"],
            "device": config["device"],
            "timestamp": datetime.now().isoformat(),
            "queue_size": transcription_queue.qsize(),
            "active_transcriptions": active_transcriptions,
            "max_concurrent": config.get("max_concurrent_transcriptions", 8),
        }
    )


@app.route("/api/config", methods=["GET"])
def get_config():
    """获取服务器配置"""
    return jsonify(
        {
            "model_size": config["model_size"],
            "device": config["device"],
            "compute_type": config["compute_type"],
            "language": config.get("language"),
            "network_mode": config.get("network_mode", "lan"),
            "workers": config.get("workers", 4),
            "max_concurrent_transcriptions": config.get(
                "max_concurrent_transcriptions", 8
            ),
            "queue_size": config.get("queue_size", 100),
        }
    )


@app.route("/api/status", methods=["GET"])
def get_status():
    """获取详细状态信息"""
    return jsonify(
        {
            "status": "running",
            "queue": {
                "size": transcription_queue.qsize(),
                "max_size": transcription_queue.maxsize,
                "active_transcriptions": active_transcriptions,
                "max_concurrent": config.get("max_concurrent_transcriptions", 8),
            },
            "model": {
                "size": config["model_size"],
                "device": config["device"],
                "compute_type": config["compute_type"],
            },
            "performance": {
                "total_requests": getattr(app, "total_requests", 0),
                "successful_requests": getattr(app, "successful_requests", 0),
                "failed_requests": getattr(app, "failed_requests", 0),
            },
        }
    )


@app.route("/api/transcribe", methods=["POST"])
def transcribe():
    """音频转写端点（支持队列管理）"""
    global active_transcriptions

    try:
        # 统计请求
        app.total_requests = getattr(app, "total_requests", 0) + 1

        if not request.is_json:
            app.failed_requests = getattr(app, "failed_requests", 0) + 1
            return (
                jsonify({"success": False, "error": "Request must be in JSON format"}),
                400,
            )

        data = request.get_json()

        # 验证必需字段
        if "audio_data" not in data:
            app.failed_requests = getattr(app, "failed_requests", 0) + 1
            return jsonify({"success": False, "error": "Missing audio_data field"}), 400

        # 生成请求ID
        request_id = f"req_{int(time.time() * 1000)}_{hash(str(data['audio_data'])[:16]) % 10000}"

        # 转换音频数据
        audio_array = np.array(data["audio_data"], dtype=np.float32)

        # 获取可选参数
        language = data.get("language")
        initial_prompt = data.get("initial_prompt")

        logger.info(
            f"Received transcription request (ID: {request_id}): audio length {len(audio_array)} samples"
        )

        # 检查并发限制
        max_concurrent = config.get("max_concurrent_transcriptions", 8)
        if active_transcriptions >= max_concurrent:
            # 检查队列是否已满
            if transcription_queue.full():
                app.failed_requests = getattr(app, "failed_requests", 0) + 1
                return (
                    jsonify(
                        {
                            "success": False,
                            "error": "Server overloaded - too many concurrent requests",
                            "queue_size": transcription_queue.qsize(),
                            "active_transcriptions": active_transcriptions,
                        }
                    ),
                    503,
                )

        # 提交到异步处理
        future = transcription_executor.submit(
            TranscriptionService.transcribe_audio_async,
            audio_array,
            language,
            initial_prompt,
            request_id,
        )

        # 等待结果（带超时）
        timeout = config.get("timeout", 600)
        try:
            result = future.result(timeout=timeout)
            if result["success"]:
                app.successful_requests = getattr(app, "successful_requests", 0) + 1
            else:
                app.failed_requests = getattr(app, "failed_requests", 0) + 1
            return jsonify(result)
        except Exception as e:
            app.failed_requests = getattr(app, "failed_requests", 0) + 1
            logger.error(f"Transcription timeout or error (ID: {request_id}): {e}")
            return (
                jsonify(
                    {
                        "success": False,
                        "request_id": request_id,
                        "error": f"Transcription failed: {str(e)}",
                    }
                ),
                500,
            )

    except Exception as e:
        app.failed_requests = getattr(app, "failed_requests", 0) + 1
        logger.error(f"Error processing transcription request: {str(e)}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/transcribe_binary", methods=["POST"])
def transcribe_binary():
    """二进制音频数据转写端点"""
    global active_transcriptions

    try:
        app.total_requests = getattr(app, "total_requests", 0) + 1

        # 获取参数
        language = request.headers.get("X-Language")
        initial_prompt = request.headers.get("X-Initial-Prompt")

        # 读取二进制音频数据
        audio_bytes = request.data

        if not audio_bytes:
            app.failed_requests = getattr(app, "failed_requests", 0) + 1
            return jsonify({"success": False, "error": "No audio data received"}), 400

        # 转换为numpy数组
        audio_array = np.frombuffer(audio_bytes, dtype=np.int16)
        audio_array = audio_array.astype(np.float32) / 32768.0

        request_id = f"bin_{int(time.time() * 1000)}"

        logger.info(
            f"Received binary transcription request (ID: {request_id}): audio length {len(audio_array)} samples"
        )

        # 检查并发限制
        max_concurrent = config.get("max_concurrent_transcriptions", 8)
        if active_transcriptions >= max_concurrent:
            if transcription_queue.full():
                app.failed_requests = getattr(app, "failed_requests", 0) + 1
                return (
                    jsonify(
                        {
                            "success": False,
                            "error": "Server overloaded - too many concurrent requests",
                            "queue_size": transcription_queue.qsize(),
                            "active_transcriptions": active_transcriptions,
                        }
                    ),
                    503,
                )

        # 异步处理
        future = transcription_executor.submit(
            TranscriptionService.transcribe_audio_async,
            audio_array,
            language,
            initial_prompt,
            request_id,
        )

        # 等待结果
        timeout = config.get("timeout", 600)
        try:
            result = future.result(timeout=timeout)
            if result["success"]:
                app.successful_requests = getattr(app, "successful_requests", 0) + 1
            else:
                app.failed_requests = getattr(app, "failed_requests", 0) + 1
            return jsonify(result)
        except Exception as e:
            app.failed_requests = getattr(app, "failed_requests", 0) + 1
            return (
                jsonify(
                    {
                        "success": False,
                        "request_id": request_id,
                        "error": f"Transcription failed: {str(e)}",
                    }
                ),
                500,
            )

    except Exception as e:
        app.failed_requests = getattr(app, "failed_requests", 0) + 1
        logger.error(
            f"Error processing binary transcription request: {str(e)}", exc_info=True
        )
        return jsonify({"success": False, "error": str(e)}), 500


@app.errorhandler(404)
def not_found(error):
    return jsonify({"success": False, "error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({"success": False, "error": "Internal server error"}), 500


def main():
    """启动服务器"""
    global config, model

    # 加载配置
    config = load_config()

    # 初始化模型
    initialize_model()

    # 配置CORS
    configure_cors()

    # 启动转写工作线程
    start_transcription_workers()

    host = config.get("host", "0.0.0.0")
    port = config.get("port", 5000)

    logger.info("=" * 60)
    logger.info("Audio Transcription Service Starting")
    logger.info(f"Address: http://{host}:{port}")
    logger.info(f"Model: {config['model_size']}")
    logger.info(f"Device: {config['device']}")
    logger.info(f"Network Mode: {config.get('network_mode', 'lan')}")
    logger.info(
        f"Max Concurrent Transcriptions: {config.get('max_concurrent_transcriptions', 8)}"
    )
    logger.info(f"Queue Size: {config.get('queue_size', 100)}")

    if host == "0.0.0.0":
        logger.info(f"LAN access: http://<your-ip>:{port}")

    logger.info("=" * 60)

    # 启动Flask服务
    app.run(host=host, port=port, debug=False, threaded=True)


if __name__ == "__main__":
    main()
