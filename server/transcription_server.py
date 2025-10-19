#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Audio Transcription Server
Provides REST API for speech-to-text with concurrent processing and queue management
"""

# 在导入任何 CUDA/cuDNN 相关库之前设置环境变量
import os
import sys
import subprocess
import json as json_module


def _setup_cuda_env_early():
    """在导入 CUDA 库之前设置环境变量并预加载 cuDNN 库"""
    import ctypes
    import glob

    try:
        # 获取 conda 环境路径
        conda_prefix = os.environ.get("CONDA_PREFIX")

        if not conda_prefix:
            # 尝试通过 conda 命令获取
            try:
                result = subprocess.run(
                    ["conda", "info", "--json"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if result.returncode == 0:
                    conda_info = json_module.loads(result.stdout)
                    conda_prefix = conda_info.get("conda_prefix")
            except Exception:
                pass

        if conda_prefix:
            # 尝试多个可能的 cuDNN 库路径
            cudnn_paths = [
                os.path.join(
                    conda_prefix,
                    "lib",
                    "python3.10",
                    "site-packages",
                    "nvidia",
                    "cudnn",
                    "lib",
                ),
                os.path.join(
                    conda_prefix,
                    "lib",
                    "python3.11",
                    "site-packages",
                    "nvidia",
                    "cudnn",
                    "lib",
                ),
                os.path.join(
                    conda_prefix,
                    "lib",
                    "python3.9",
                    "site-packages",
                    "nvidia",
                    "cudnn",
                    "lib",
                ),
                os.path.join(
                    conda_prefix,
                    "lib",
                    "python3.12",
                    "site-packages",
                    "nvidia",
                    "cudnn",
                    "lib",
                ),
                os.path.join(conda_prefix, "lib"),
            ]

            # 同时检查 conda 的 lib 目录
            conda_lib = os.path.join(conda_prefix, "lib")

            # 收集所有有效路径
            all_valid_paths = []
            for path in cudnn_paths:
                if os.path.exists(path):
                    all_valid_paths.append(path)

            # 确保 conda lib 目录在列表中
            if os.path.exists(conda_lib) and conda_lib not in all_valid_paths:
                all_valid_paths.append(conda_lib)

            if all_valid_paths:
                # 设置 LD_LIBRARY_PATH (包含所有有效路径)
                current_ld = os.environ.get("LD_LIBRARY_PATH", "")
                new_paths = ":".join(all_valid_paths)
                new_ld = f"{new_paths}:{current_ld}" if current_ld else new_paths
                os.environ["LD_LIBRARY_PATH"] = new_ld

                # 对 macOS 也设置 DYLD_LIBRARY_PATH
                if sys.platform == "darwin":
                    current_dyld = os.environ.get("DYLD_LIBRARY_PATH", "")
                    new_dyld = (
                        f"{new_paths}:{current_dyld}" if current_dyld else new_paths
                    )
                    os.environ["DYLD_LIBRARY_PATH"] = new_dyld

                # 使用 ctypes 显式预加载 cuDNN 库文件
                # 这是关键步骤：在 faster_whisper 加载之前强制加载 cuDNN
                cudnn_libs_loaded = []
                for path in all_valid_paths:
                    try:
                        # 查找所有 cuDNN 相关的 .so 文件
                        cudnn_patterns = [
                            "libcudnn.so*",
                            "libcudnn_*.so*",
                            "libcudnn_ops*.so*",
                            "libcudnn_cnn*.so*",
                        ]

                        for pattern in cudnn_patterns:
                            lib_files = glob.glob(os.path.join(path, pattern))
                            for lib_file in lib_files:
                                try:
                                    # 使用 RTLD_GLOBAL 确保库符号全局可见
                                    ctypes.CDLL(lib_file, mode=ctypes.RTLD_GLOBAL)
                                    cudnn_libs_loaded.append(os.path.basename(lib_file))
                                except Exception:
                                    continue
                    except Exception:
                        continue

                # 记录预加载的库（仅在有库被加载时输出）
                if cudnn_libs_loaded:
                    print(
                        f"[CUDA Setup] Successfully preloaded {len(cudnn_libs_loaded)} cuDNN libraries",
                        file=sys.stderr,
                        flush=True,
                    )

    except Exception as e:
        print(
            f"[CUDA Setup] Warning during early CUDA setup: {e}",
            file=sys.stderr,
            flush=True,
        )


# 在导入 faster_whisper 前设置环境
_setup_cuda_env_early()

from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import logging
from faster_whisper import WhisperModel
import io
import json
from datetime import datetime
import threading
import queue
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import gc
from contextlib import contextmanager
import socket
from llm_service import LLMService

# Configure logging
def setup_logging():
    """Configure application logging with file and console handlers"""
    import os
    from logging.handlers import RotatingFileHandler

    # Get log directory from environment or use default
    log_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "logs")
    os.makedirs(log_dir, exist_ok=True)

    # Application log file (separate from Gunicorn logs)
    app_log_file = os.path.join(log_dir, "application.log")

    # Create formatter
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

    # File handler with rotation
    file_handler = RotatingFileHandler(
        app_log_file,
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)

    # Console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(formatter)

    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)

    # Remove existing handlers to avoid duplicates
    root_logger.handlers.clear()

    # Add handlers
    root_logger.addHandler(file_handler)
    root_logger.addHandler(console_handler)

    return root_logger

# Setup logging
setup_logging()
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global variables
transcription_queue = queue.Queue(maxsize=100)  # 请求队列
active_transcriptions = 0  # 活跃转写计数
transcription_executor = None  # 线程池
model = None
config = None
llm_service = None  # LLM服务实例
lock = threading.Lock()


def setup_cuda_environment():
    """设置 CUDA 和 cuDNN 环境变量（修复开发服务器库加载问题）"""
    import subprocess

    try:
        # 获取 conda 环境路径
        conda_prefix = os.environ.get("CONDA_PREFIX")

        if not conda_prefix:
            # 尝试通过 conda 命令获取环境信息
            try:
                result = subprocess.run(
                    ["conda", "info", "--json"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if result.returncode == 0:
                    conda_info = json.loads(result.stdout)
                    conda_prefix = conda_info.get("conda_prefix")
            except Exception:
                pass

        if not conda_prefix:
            logger.warning(
                "Could not determine conda environment path, skipping CUDA environment setup"
            )
            return

        # 构建 cuDNN 库路径（支持多个 Python 版本）
        cudnn_paths = [
            os.path.join(
                conda_prefix,
                "lib",
                "python3.10",
                "site-packages",
                "nvidia",
                "cudnn",
                "lib",
            ),
            os.path.join(
                conda_prefix,
                "lib",
                "python3.11",
                "site-packages",
                "nvidia",
                "cudnn",
                "lib",
            ),
            os.path.join(
                conda_prefix,
                "lib",
                "python3.9",
                "site-packages",
                "nvidia",
                "cudnn",
                "lib",
            ),
            os.path.join(
                conda_prefix,
                "lib",
                "python3.12",
                "site-packages",
                "nvidia",
                "cudnn",
                "lib",
            ),
            os.path.join(conda_prefix, "lib"),  # 备用路径
        ]

        # 查找有效的 cuDNN 库路径
        valid_cudnn_path = None
        for path in cudnn_paths:
            if os.path.exists(path):
                logger.info(f"Found cuDNN library path: {path}")
                valid_cudnn_path = path
                break

        if valid_cudnn_path:
            # 设置 LD_LIBRARY_PATH（Linux/Unix）
            current_ld_path = os.environ.get("LD_LIBRARY_PATH", "")
            new_ld_path = (
                f"{valid_cudnn_path}:{current_ld_path}"
                if current_ld_path
                else valid_cudnn_path
            )
            os.environ["LD_LIBRARY_PATH"] = new_ld_path
            logger.info(f"Set LD_LIBRARY_PATH to include: {valid_cudnn_path}")

            # 对于 macOS，也设置 DYLD_LIBRARY_PATH
            if os.name == "posix":
                import platform

                if platform.system() == "Darwin":
                    current_dyld_path = os.environ.get("DYLD_LIBRARY_PATH", "")
                    new_dyld_path = (
                        f"{valid_cudnn_path}:{current_dyld_path}"
                        if current_dyld_path
                        else valid_cudnn_path
                    )
                    os.environ["DYLD_LIBRARY_PATH"] = new_dyld_path
                    logger.info(f"Set DYLD_LIBRARY_PATH for macOS: {valid_cudnn_path}")
        else:
            logger.warning("cuDNN library path not found in conda environment")

    except Exception as e:
        logger.warning(f"Failed to setup CUDA environment: {e}")
        # 继续执行，不中断启动


# 确保在worker进程启动时初始化模型
def init_worker():
    """Gunicorn worker初始化函数"""
    logger.info("Initializing Gunicorn worker...")
    global model, config, llm_service
    try:
        # 设置 CUDA 环境（在 worker 进程启动时）
        setup_cuda_environment()
        config = load_config()
        initialize_model()
        initialize_llm_service()
        logger.info("Worker initialization completed successfully")
    except Exception as e:
        logger.error(f"Worker initialization failed: {e}", exc_info=True)
        raise e


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
    logger.info(f"Device: {config['device']}, Compute type: {config['compute_type']}")

    try:
        model_size = config["model_size"]
        # 优先使用Systran的Faster Whisper模型
        logger.info(f"Attempting to load Systran Faster Whisper model: {model_size}")
        model = WhisperModel(
            model_size,
            device=config["device"],
            compute_type=config["compute_type"],
            local_files_only=False,
        )
        logger.info("Systran Faster Whisper model loaded successfully")

        # 测试模型是否可用
        logger.info("Testing model availability...")
        test_audio = np.zeros(16000, dtype=np.float32)  # 1秒的静音音频
        test_segments = list(model.transcribe(test_audio, language="zh"))
        logger.info("Model test completed successfully")

    except Exception as e:
        logger.error(f"Failed to load Systran model {config['model_size']}: {e}")
        logger.error(f"Error details: {str(e)}", exc_info=True)
        logger.info("Falling back to base model")
        try:
            model = WhisperModel(
                "base", device=config["device"], compute_type=config["compute_type"]
            )
            logger.info("Base model loaded as fallback")

            # 测试回退模型
            test_audio = np.zeros(16000, dtype=np.float32)
            test_segments = list(model.transcribe(test_audio, language="zh"))
            logger.info("Base model test completed successfully")

        except Exception as fallback_error:
            logger.error(f"Failed to load base model: {fallback_error}")
            logger.error(
                f"Base model error details: {str(fallback_error)}", exc_info=True
            )
            raise fallback_error


# Initialize LLM Service
def initialize_llm_service():
    global llm_service
    try:
        llm_config = config.get("llm", {})
        llm_service = LLMService(llm_config)

        # Validate configuration
        is_valid, error_msg = llm_service.validate_config()
        if not is_valid:
            logger.warning(f"LLM service validation failed: {error_msg}")
        elif llm_service.is_enabled():
            logger.info(f"LLM service initialized - Model: {llm_service.model}")
        else:
            logger.info("LLM service is disabled")

    except Exception as e:
        logger.error(f"Failed to initialize LLM service: {e}", exc_info=True)
        llm_service = None


# Configure CORS
def configure_cors():
    if config.get("network_mode") == "internet":
        CORS(app)
        logger.info("Network mode: Internet - CORS enabled")
    else:
        CORS(app, resources={r"/api/*": {"origins": "*"}})
        logger.info("Network mode: LAN")


def get_local_ip():
    """获取本地IP地址（单个，用于向后兼容）"""
    ips = get_all_local_ips()
    # 返回第一个非127.0.0.1的IP地址，如果没有则返回127.0.0.1
    for ip in ips:
        if not ip.startswith("127.") and not ip.startswith("169.254"):
            return ip
    return ips[0] if ips else "127.0.0.1"


def get_all_local_ips():
    """获取所有本地IP地址"""
    ips = []

    try:
        # 方法1：通过连接到外部地址获取默认路由IP（优先）
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                default_ip = s.getsockname()[0]
                if (
                    default_ip not in ips
                    and not default_ip.startswith("127.")
                    and not default_ip.startswith("169.254.")
                ):
                    ips.insert(0, default_ip)  # 插入到开头，因为这是主要网络接口
        except Exception as e:
            logger.warning(f"获取默认路由IP失败: {e}")

        # 方法2：使用hostname -I命令获取所有IP（最可靠）
        try:
            import subprocess

            result = subprocess.run(
                ["hostname", "-I"], capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                hostname_ips = result.stdout.strip().split()
                for ip in hostname_ips:
                    if (
                        ip not in ips
                        and not ip.startswith("127.")
                        and not ip.startswith("169.254.")
                        and ":" not in ip
                    ):  # 排除IPv6
                        ips.append(ip)
        except Exception as e:
            logger.warning(f"通过hostname -I获取IP地址失败: {e}")

        # 方法3：通过ip命令获取所有IP（Linux系统）
        try:
            import subprocess

            result = subprocess.run(
                ["ip", "addr", "show"], capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                import re

                # 使用正则表达式提取IPv4地址
                ip_pattern = r"inet (\d+\.\d+\.\d+\.\d+/\d+)"
                for line in result.stdout.split("\n"):
                    match = re.search(ip_pattern, line)
                    if match:
                        ip_with_mask = match.group(1)
                        ip = ip_with_mask.split("/")[0]  # 去掉子网掩码
                        if (
                            ip not in ips
                            and not ip.startswith("127.")
                            and not ip.startswith("169.254.")
                            and not ip.startswith("0.")
                        ):
                            ips.append(ip)
        except Exception as e:
            logger.warning(f"通过ip命令获取IP地址失败: {e}")

        # 方法4：通过ifconfig命令获取所有IP（备用）
        try:
            import subprocess

            result = subprocess.run(
                ["ifconfig"], capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                import re

                # 使用正则表达式提取IPv4地址
                ip_pattern = r"inet (\d+\.\d+\.\d+\.\d+)"
                for line in result.stdout.split("\n"):
                    match = re.search(ip_pattern, line)
                    if match:
                        ip = match.group(1)
                        if (
                            ip not in ips
                            and not ip.startswith("127.")
                            and not ip.startswith("169.254.")
                            and not ip.startswith("0.")
                        ):
                            ips.append(ip)
        except Exception as e:
            logger.warning(f"通过ifconfig获取IP地址失败: {e}")

        # 方法5：通过主机名获取IP（最后的备用方法）
        try:
            hostname = socket.gethostname()
            addr_info = socket.getaddrinfo(hostname, None)
            for info in addr_info:
                ip = info[4][0]
                if (
                    ":" not in ip  # 排除IPv6
                    and not ip.startswith("127.")  # 排除本地回环
                    and not ip.startswith("169.254.")  # 排除链路本地地址
                    and ip not in ips
                ):
                    ips.append(ip)
        except Exception as e:
            logger.warning(f"通过主机名获取IP地址失败: {e}")

        # 如果没有获取到任何IP，至少添加本地回环地址
        if not ips:
            ips.append("127.0.0.1")

    except Exception as e:
        logger.error(f"获取IP地址时发生错误: {e}")
        ips.append("127.0.0.1")

    return ips


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

                # Try to polish text with LLM if enabled
                polished_text = full_text.strip()
                llm_used = False
                llm_error = None

                if llm_service and llm_service.is_enabled():
                    original_text = full_text.strip()
                    logger.info(
                        f"Attempting to polish text with LLM (ID: {request_id})"
                    )
                    logger.info(
                        f"Original text before LLM (ID: {request_id}): {original_text}"
                    )

                    polished_result, success, error_msg = llm_service.polish_text(
                        original_text
                    )

                    if success and polished_result:
                        polished_text = polished_result
                        llm_used = True
                        logger.info(
                            f"Text polished successfully by LLM (ID: {request_id})"
                        )
                        logger.info(
                            f"Polished text after LLM (ID: {request_id}): {polished_text}"
                        )

                        # Log comparison if text changed
                        if original_text != polished_text:
                            logger.info(
                                f"LLM text comparison (ID: {request_id}):\n"
                                f"  [BEFORE]: {original_text}\n"
                                f"  [AFTER]:  {polished_text}"
                            )
                        else:
                            logger.info(
                                f"LLM did not change the text (ID: {request_id})"
                            )
                    else:
                        # LLM failed, use original text
                        logger.warning(
                            f"LLM polishing failed for request {request_id}: {error_msg}. "
                            "Using original text as fallback."
                        )
                        llm_error = error_msg

                result = {
                    "success": True,
                    "request_id": request_id,
                    "language": info.language,
                    "language_probability": info.language_probability,
                    "segments": segment_list,
                    "text": polished_text,
                    "original_text": full_text.strip(),  # 保存原始文本供参考
                    "llm_used": llm_used,
                    "llm_error": llm_error if llm_error else None,
                    "duration": info.duration if hasattr(info, "duration") else None,
                    "processing_time": None,  # 将在外部计算
                }

                logger.info(
                    f"Transcription completed (ID: {request_id}): {len(segment_list)} segments, "
                    f"LLM polished: {llm_used}"
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
    try:
        # 确保模型和配置已初始化
        ensure_initialized()

        # 检查模型是否已加载
        if model is None:
            logger.error("Health check failed: Model not loaded")
            return (
                jsonify(
                    {
                        "status": "unhealthy",
                        "error": "Model not loaded",
                        "success": False,
                    }
                ),
                503,
            )

        # 检查配置是否加载
        if config is None:
            logger.error("Health check failed: Configuration not loaded")
            return (
                jsonify(
                    {
                        "status": "unhealthy",
                        "error": "Configuration not loaded",
                        "success": False,
                    }
                ),
                503,
            )

        return jsonify(
            {
                "status": "healthy",
                "model": config["model_size"],
                "device": config["device"],
                "timestamp": datetime.now().isoformat(),
                "queue_size": transcription_queue.qsize(),
                "active_transcriptions": active_transcriptions,
                "max_concurrent": config.get("max_concurrent_transcriptions", 8),
                "worker_count": config.get("workers", 1),
                "model_loaded": model is not None,
                "config_loaded": config is not None,
            }
        )
    except Exception as e:
        logger.error(f"Health check failed with error: {str(e)}", exc_info=True)
        return jsonify({"status": "unhealthy", "error": str(e), "success": False}), 500


@app.route("/api/config", methods=["GET"])
def get_config():
    """获取服务器配置"""
    try:
        # 确保配置已初始化
        ensure_initialized()

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
    except Exception as e:
        logger.error(f"Config check failed with error: {str(e)}", exc_info=True)
        return jsonify({"error": str(e), "success": False}), 500


@app.route("/api/status", methods=["GET"])
def get_status():
    """获取详细状态信息"""
    try:
        # 简化版本，先不调用ensure_initialized
        return jsonify(
            {
                "status": "running",
                "message": "Basic status endpoint working",
                "timestamp": datetime.now().isoformat(),
            }
        )
    except Exception as e:
        logger.error(f"Status check failed with error: {str(e)}", exc_info=True)
        return jsonify({"status": "error", "error": str(e), "success": False}), 500


@app.route("/api/transcribe", methods=["POST"])
def transcribe():
    """音频转写端点（支持队列管理）"""
    global active_transcriptions

    try:
        # 确保配置和���型已初始化
        ensure_initialized()

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
        # 确保配置和模型已初始化
        ensure_initialized()

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


@app.route("/api/llm/health", methods=["GET"])
def llm_health_check():
    """LLM服务健康检查端点"""
    try:
        ensure_initialized()

        if llm_service is None:
            return (
                jsonify(
                    {
                        "status": "disabled",
                        "message": "LLM service is not initialized",
                        "success": False,
                    }
                ),
                200,
            )

        if not llm_service.is_enabled():
            return (
                jsonify(
                    {
                        "status": "disabled",
                        "message": "LLM service is disabled in configuration",
                        "success": True,
                    }
                ),
                200,
            )

        # Validate configuration
        is_valid, error_msg = llm_service.validate_config()
        if not is_valid:
            return (
                jsonify(
                    {
                        "status": "misconfigured",
                        "message": error_msg,
                        "success": False,
                    }
                ),
                400,
            )

        # Check API health
        is_healthy, status_msg = llm_service.health_check()
        if is_healthy:
            return (
                jsonify(
                    {
                        "status": "healthy",
                        "message": status_msg,
                        "model": llm_service.model,
                        "api_url": llm_service.api_url,
                        "success": True,
                    }
                ),
                200,
            )
        else:
            return (
                jsonify(
                    {
                        "status": "unhealthy",
                        "message": status_msg,
                        "model": llm_service.model,
                        "api_url": llm_service.api_url,
                        "success": False,
                    }
                ),
                503,
            )

    except Exception as e:
        logger.error(f"LLM health check failed: {str(e)}", exc_info=True)
        return (
            jsonify(
                {
                    "status": "error",
                    "message": str(e),
                    "success": False,
                }
            ),
            500,
        )


@app.errorhandler(404)
def not_found(error):
    return jsonify({"success": False, "error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({"success": False, "error": "Internal server error"}), 500


def ensure_initialized():
    """确保在worker进程中模型和配置已初始化"""
    global config, model, transcription_executor, llm_service
    if config is None or model is None:
        logger.info("Initializing model and config in worker process...")
        # 也在 worker 进程中设置 CUDA 环境
        setup_cuda_environment()
        config = load_config()
        initialize_model()
        initialize_llm_service()

        # 确保转写工作线程已启动
        if transcription_executor is None:
            start_transcription_workers()

        logger.info("Worker process initialization completed")


def main():
    """启动服务器"""
    global config, model, llm_service

    # 设置 cuDNN 和 CUDA 库路径（修复开发服务器库加载问题）
    setup_cuda_environment()

    # 加载配置
    config = load_config()

    # 初始化模型
    initialize_model()

    # 初始化LLM服务
    initialize_llm_service()

    # 配置CORS
    configure_cors()

    # 启动转写工作线程
    start_transcription_workers()

    host = config.get("host", "0.0.0.0")
    port = config.get("port", 5000)

    # 获取所有本地IP地址
    all_ips = get_all_local_ips()
    local_ip = get_local_ip()  # 用于向后兼容的主要IP

    logger.info("=" * 60)
    logger.info("Audio Transcription Service Starting")
    logger.info(f"Address: http://{host}:{port}")
    logger.info(f"Primary IP: {local_ip}")

    if len(all_ips) > 1:
        logger.info("All Available IP Addresses:")
        for ip in all_ips:
            logger.info(f"  - http://{ip}:{port}")
    else:
        logger.info(f"Local IP: {local_ip}")

    logger.info(f"Model: {config['model_size']}")
    logger.info(f"Device: {config['device']}")
    logger.info(f"Network Mode: {config.get('network_mode', 'lan')}")
    logger.info(
        f"Max Concurrent Transcriptions: {config.get('max_concurrent_transcriptions', 8)}"
    )
    logger.info(f"Queue Size: {config.get('queue_size', 100)}")

    if host == "0.0.0.0":
        if len(all_ips) > 1:
            logger.info("LAN Access URLs:")
            for ip in all_ips:
                logger.info(f"  - http://{ip}:{port}")
        else:
            logger.info(f"LAN access: http://{local_ip}:{port}")

    logger.info("=" * 60)

    # 启动Flask服务
    app.run(host=host, port=port, debug=True, threaded=True)


if __name__ == "__main__":
    main()
