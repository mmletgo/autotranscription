#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Audio Transcription Server
Provides REST API for speech-to-text using Whisper model
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

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)


# Load configuration
def load_config():
    config_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)), "config", "server_config.json"
    )
    if os.path.exists(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {
        "model_size": "base",
        "device": "cpu",
        "compute_type": "int8",
        "language": "zh",
        "initial_prompt": "The following are sentences in Mandarin.",
        "host": "0.0.0.0",  # 0.0.0.0 for LAN access, 127.0.0.1 for localhost only
        "port": 5000,
        "network_mode": "lan",  # "lan" or "internet"
    }


config = load_config()

# Configure CORS based on network mode
if config.get("network_mode") == "internet":
    CORS(app)  # Allow all cross-origin requests
    logger.info("Network mode: Internet - CORS enabled")
else:
    # LAN mode with restricted CORS
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    logger.info("Network mode: LAN")

# Initialize Whisper model
logger.info(f"Loading Whisper model: {config['model_size']}")
model = WhisperModel(
    config["model_size"], device=config["device"], compute_type=config["compute_type"]
)
logger.info("Model loading completed")


class TranscriptionService:
    """Audio transcription service"""

    @staticmethod
    def transcribe_audio(
        audio_data, language=None, initial_prompt=None, streaming=False
    ):
        """
        Transcribe audio data

        Args:
            audio_data: Audio data in numpy array format (float32, [-1, 1])
            language: Language code (e.g. 'zh', 'en')
            initial_prompt: Initial prompt text
            streaming: Whether to use streaming output

        Returns:
            dict: Transcription result
        """
        try:
            # Use default values from config
            if language is None:
                language = config.get("language")
            if initial_prompt is None:
                initial_prompt = config.get("initial_prompt")

            logger.info(
                f"Starting audio transcription (language: {language}, streaming: {streaming})"
            )

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

            # Collect all segments
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
                "language": info.language,
                "language_probability": info.language_probability,
                "segments": segment_list,
                "text": full_text.strip(),
                "duration": info.duration if hasattr(info, "duration") else None,
            }

            logger.info(f"Transcription completed: {len(segment_list)} segments")
            return result

        except Exception as e:
            logger.error(f"Transcription failed: {str(e)}", exc_info=True)
            return {"success": False, "error": str(e)}


# API Routes


@app.route("/api/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    return jsonify(
        {
            "status": "healthy",
            "model": config["model_size"],
            "device": config["device"],
            "timestamp": datetime.now().isoformat(),
        }
    )


@app.route("/api/config", methods=["GET"])
def get_config():
    """Get server configuration"""
    return jsonify(
        {
            "model_size": config["model_size"],
            "device": config["device"],
            "compute_type": config["compute_type"],
            "language": config.get("language"),
            "network_mode": config.get("network_mode", "lan"),
        }
    )


@app.route("/api/transcribe", methods=["POST"])
def transcribe():
    """
    Audio transcription endpoint

    Receives audio data (JSON format) and returns transcription result

    Request body format:
    {
        "audio_data": [audio data array],
        "sample_rate": 16000,
        "language": "zh",  // optional
        "initial_prompt": "The following are sentences in Mandarin.",  // optional
        "streaming": false  // optional
    }
    """
    try:
        if not request.is_json:
            return (
                jsonify({"success": False, "error": "Request must be in JSON format"}),
                400,
            )

        data = request.get_json()

        # Validate required fields
        if "audio_data" not in data:
            return jsonify({"success": False, "error": "Missing audio_data field"}), 400

        # Convert audio data
        audio_array = np.array(data["audio_data"], dtype=np.float32)

        # Get optional parameters
        language = data.get("language")
        initial_prompt = data.get("initial_prompt")
        streaming = data.get("streaming", False)

        logger.info(
            f"Received transcription request: audio length {len(audio_array)} samples"
        )

        # Perform transcription
        result = TranscriptionService.transcribe_audio(
            audio_array,
            language=language,
            initial_prompt=initial_prompt,
            streaming=streaming,
        )

        return jsonify(result)

    except Exception as e:
        logger.error(f"Error processing transcription request: {str(e)}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/transcribe_binary", methods=["POST"])
def transcribe_binary():
    """
    Audio transcription endpoint (binary audio data)

    Receives raw audio data (binary) and returns transcription result
    Supports more efficient data transmission

    Request headers should include:
    - Content-Type: application/octet-stream
    - X-Sample-Rate: 16000 (optional, default 16000)
    - X-Language: zh (optional)
    - X-Initial-Prompt: ... (optional)
    """
    try:
        # Get parameters from request headers
        language = request.headers.get("X-Language")
        initial_prompt = request.headers.get("X-Initial-Prompt")

        # Read binary audio data
        audio_bytes = request.data

        if not audio_bytes:
            return jsonify({"success": False, "error": "No audio data received"}), 400

        # Convert to numpy array (assuming int16 format)
        audio_array = np.frombuffer(audio_bytes, dtype=np.int16)
        audio_array = audio_array.astype(np.float32) / 32768.0

        logger.info(
            f"Received binary transcription request: audio length {len(audio_array)} samples"
        )

        # Perform transcription
        result = TranscriptionService.transcribe_audio(
            audio_array, language=language, initial_prompt=initial_prompt
        )

        return jsonify(result)

    except Exception as e:
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
    """Start the server"""
    host = config.get("host", "0.0.0.0")
    port = config.get("port", 5000)

    logger.info("=" * 50)
    logger.info("Audio Transcription Service Starting")
    logger.info(f"Address: http://{host}:{port}")
    logger.info(f"Model: {config['model_size']}")
    logger.info(f"Device: {config['device']}")
    logger.info(f"Network Mode: {config.get('network_mode', 'lan')}")

    if host == "0.0.0.0":
        logger.info(f"LAN access: http://<your-ip>:{port}")

    logger.info("=" * 50)

    # Start Flask service
    app.run(host=host, port=port, debug=False, threaded=True)


if __name__ == "__main__":
    main()
