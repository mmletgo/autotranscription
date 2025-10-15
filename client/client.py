#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Audio Transcription Client
Calls remote server API for speech-to-text transcription
"""

import enum
import time
import threading
import argparse
import platform
import pyaudio
import numpy as np
from pynput import keyboard
from transitions import Machine
import pyperclip
import requests
import json
import os

try:
    from opencc import OpenCC
except Exception:
    OpenCC = None

if platform.system() == "Windows":
    import winsound

    def playsound(s, wait=True):
        winsound.PlaySound(s, winsound.SND_MEMORY)

    def loadwav(filename):
        with open(filename, "rb") as f:
            data = f.read()
        return data

else:
    import soundfile as sf
    import sounddevice

    sounddevice.default.samplerate = 44100
    _audio_device = None  # Will be set from config

    def playsound(s, wait=True):
        # s is a tuple of (data, samplerate)
        if isinstance(s, tuple):
            data, fs = s
            sounddevice.play(data, fs, device=_audio_device)
        else:
            sounddevice.play(s, device=_audio_device)
        if wait:
            sounddevice.wait()

    def loadwav(filename):
        data, fs = sf.read(filename, dtype="float32")
        return (data, fs)  # Return both data and sample rate

    def set_audio_device(device_id):
        global _audio_device
        _audio_device = device_id


class SpeechTranscriberClient:
    """Speech transcription client - calls remote API"""

    def __init__(
        self, callback, server_url, language=None, initial_prompt=None, streaming=False
    ):
        self.callback = callback
        self.server_url = server_url.rstrip("/")
        self.language = language
        self.initial_prompt = initial_prompt
        self.streaming = streaming
        self.session = requests.Session()

        # Disable proxy for LAN connections to avoid proxy interference
        # This is especially important when connecting to local servers like 192.168.x.x
        self.session.trust_env = False

        # Test server connection
        self._test_connection()

    def _test_connection(self):
        """Test server connection"""
        try:
            response = self.session.get(f"{self.server_url}/api/health", timeout=5)
            if response.status_code == 200:
                data = response.json()
                print("✓ Successfully connected to server")
                print(f"  Model: {data.get('model')}")
                print(f"  Device: {data.get('device')}")
            else:
                print(f"⚠ Server response abnormal: {response.status_code}")
        except requests.exceptions.ConnectionError:
            print(f"✗ Cannot connect to server: {self.server_url}")
            print("  Please ensure the server is running")
        except Exception as e:
            print(f"✗ Connection test failed: {e}")

    def transcribe(self, event):
        """Transcribe audio"""
        print("Sending audio to server for transcription...")
        audio = event.kwargs.get("audio", None)

        if audio is not None:
            try:
                # Prepare request data
                request_data = {
                    "audio_data": audio.tolist(),
                    "sample_rate": 16000,
                    "streaming": self.streaming,
                }

                if self.language:
                    request_data["language"] = self.language
                if self.initial_prompt:
                    request_data["initial_prompt"] = self.initial_prompt

                # Send request to server
                response = self.session.post(
                    f"{self.server_url}/api/transcribe", json=request_data, timeout=60
                )

                if response.status_code == 200:
                    result = response.json()

                    if result.get("success"):
                        # Convert to segment objects similar to local model
                        segments = []
                        for seg_data in result.get("segments", []):
                            segment = type(
                                "Segment",
                                (),
                                {
                                    "start": seg_data["start"],
                                    "end": seg_data["end"],
                                    "text": seg_data["text"],
                                },
                            )()
                            segments.append(segment)

                        print(
                            f"Detected language: {result.get('language')} "
                            f"(probability: {result.get('language_probability', 0):.2f})"
                        )

                        # Handle streaming or non-streaming output
                        if self.streaming:
                            for segment in segments:
                                self.callback(
                                    segments=[segment], streaming=True, final=False
                                )
                            self.callback(segments=[], streaming=True, final=True)
                        else:
                            self.callback(segments=segments)
                    else:
                        print(f"Transcription failed: {result.get('error')}")
                        self.callback(segments=[])
                else:
                    print(f"Server error: {response.status_code}")
                    self.callback(segments=[])

            except requests.exceptions.Timeout:
                print("Request timeout, please check network or server status")
                self.callback(segments=[])
            except requests.exceptions.ConnectionError as e:
                print(f"Cannot connect to server: {e}")
                print(f"Server URL: {self.server_url}/api/transcribe")
                self.callback(segments=[])
            except Exception as e:
                print(f"Error during transcription: {e}")
                import traceback
                traceback.print_exc()
                self.callback(segments=[])
        else:
            self.callback(segments=[])

    def transcribe_binary(self, audio):
        """Send audio in binary format (more efficient)"""
        try:
            # Convert to int16 format
            audio_int16 = (audio * 32768.0).astype(np.int16)
            audio_bytes = audio_int16.tobytes()

            headers = {
                "Content-Type": "application/octet-stream",
                "X-Sample-Rate": "16000",
            }

            if self.language:
                headers["X-Language"] = self.language
            if self.initial_prompt:
                headers["X-Initial-Prompt"] = self.initial_prompt

            response = self.session.post(
                f"{self.server_url}/api/transcribe_binary",
                data=audio_bytes,
                headers=headers,
                timeout=60,
            )

            if response.status_code == 200:
                return response.json()
            else:
                return {
                    "success": False,
                    "error": f"Server error: {response.status_code}",
                }

        except Exception as e:
            return {"success": False, "error": str(e)}


class Recorder:
    """Audio recorder"""

    def __init__(self, callback, streaming_callback=None):
        self.callback = callback
        self.streaming_callback = streaming_callback
        self.recording = False
        self.stream_interval = 1.0

    def start(self, language=None):
        print("Recording started...")
        thread = threading.Thread(target=self._record_impl, args=())
        thread.start()

    def stop(self):
        print("Recording stopped.")
        self.recording = False

    def _record_impl(self):
        """Internal recording implementation with error handling"""
        self.recording = True

        frames_per_buffer = 1024
        sample_rate = 16000
        p = None
        stream = None

        try:
            print("Initializing audio stream...")
            p = pyaudio.PyAudio()

            # Get default input device info for debugging
            try:
                default_input = p.get_default_input_device_info()
                print(f"Using audio device: {default_input['name']}")
            except Exception as e:
                print(f"Warning: Could not get default input device info: {e}")

            stream = p.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=sample_rate,
                frames_per_buffer=frames_per_buffer,
                input=True,
            )
            print("✓ Audio stream opened successfully")

            frames = []
            chunk_frames = []
            frames_per_chunk = int(sample_rate * self.stream_interval / frames_per_buffer)
            frame_count = 0

            print("Recording audio...")
            while self.recording:
                try:
                    data = stream.read(frames_per_buffer, exception_on_overflow=False)
                    frames.append(data)

                    if self.streaming_callback is not None:
                        chunk_frames.append(data)
                        frame_count += 1

                        if frame_count >= frames_per_chunk:
                            audio_chunk = np.frombuffer(b"".join(chunk_frames), dtype=np.int16)
                            audio_chunk_fp32 = audio_chunk.astype(np.float32) / 32768.0
                            self.streaming_callback(audio=audio_chunk_fp32)
                            chunk_frames = []
                            frame_count = 0
                except Exception as e:
                    print(f"Error reading audio frame: {e}")
                    break

            print(f"Recorded {len(frames)} frames ({len(frames) * frames_per_buffer / sample_rate:.2f}s)")

            if stream is not None:
                stream.stop_stream()
                stream.close()
            if p is not None:
                p.terminate()

            if len(frames) > 0:
                audio_data = np.frombuffer(b"".join(frames), dtype=np.int16)
                audio_data_fp32 = audio_data.astype(np.float32) / 32768.0
                print(f"Audio data prepared: {len(audio_data_fp32)} samples")
                self.callback(audio=audio_data_fp32)
            else:
                print("Warning: No audio data recorded")
                self.callback(audio=np.array([], dtype=np.float32))

        except Exception as e:
            print(f"✗ Recording error: {e}")
            import traceback
            traceback.print_exc()

            # Cleanup
            if stream is not None:
                try:
                    stream.stop_stream()
                    stream.close()
                except:
                    pass
            if p is not None:
                try:
                    p.terminate()
                except:
                    pass

            # Still call callback with empty audio to continue state machine
            self.callback(audio=np.array([], dtype=np.float32))


class KeyboardReplayer:
    """Keyboard output handler"""

    def __init__(self, callback, converter=None):
        self.callback = callback
        self.kb = keyboard.Controller()
        self.converter = converter

    def replay(self, event):
        segments = event.kwargs.get("segments", [])
        is_streaming = event.kwargs.get("streaming", False)
        is_final = event.kwargs.get("final", False)
        is_live = event.kwargs.get("live", False)

        if is_streaming:
            if is_live:
                self._type_segments(segments, streaming=True)
            elif not is_final:
                self._type_segments(segments, streaming=True)
            else:
                print("Streaming transcription completed.")
                self.callback()
        else:
            print("Pasting transcription via clipboard...")
            full_text = "".join(segment.text for segment in segments).strip()

            if self.converter is not None and full_text:
                try:
                    full_text = self.converter.convert(full_text)
                except Exception as e:
                    print(f"Chinese conversion failed: {e}")

            if not full_text:
                self.callback()
                return

            try:
                pyperclip.copy(full_text)
                print(f"Copied to clipboard: '{full_text}'")

                time.sleep(0.1)

                with self.kb.pressed(keyboard.Key.ctrl):
                    self.kb.press("v")
                    self.kb.release("v")

                print("Paste command sent.")

            except Exception as e:
                print(f"Clipboard operation error: {e}")
            finally:
                self.callback()

    def _type_segments(self, segments, streaming=False):
        """Type text segments immediately (streaming mode)"""
        for segment in segments:
            text = segment.text.strip()

            if self.converter is not None and text:
                try:
                    text = self.converter.convert(text)
                except Exception as e:
                    print(f"Chinese conversion failed: {e}")

            if text:
                try:
                    pyperclip.copy(text)
                    time.sleep(0.05)

                    with self.kb.pressed(keyboard.Key.ctrl):
                        self.kb.press("v")
                        self.kb.release("v")

                    time.sleep(0.05)
                    self.kb.type(" ")
                except Exception as e:
                    print(f"Error typing text segment: {e}")


class KeyListener:
    """Keyboard listener"""

    def __init__(self, callback, key):
        self.callback = callback
        self.key = key

    def run(self):
        with keyboard.GlobalHotKeys({self.key: self.callback}) as h:
            h.join()


def load_config():
    """Load client configuration"""
    config_path = os.path.join(
        os.path.dirname(os.path.dirname(__file__)), "config", "client_config.json"
    )
    if os.path.exists(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def parse_args():
    """Parse command line arguments"""
    config = load_config()

    parser = argparse.ArgumentParser(
        description="Audio Transcription Client (calls remote API)"
    )
    parser.add_argument(
        "-s",
        "--server-url",
        type=str,
        default=config.get("server_url", "http://localhost:5000"),
        help="Server API address, e.g.: http://192.168.1.100:5000",
    )
    parser.add_argument(
        "-k",
        "--key-combo",
        type=str,
        default=config.get("key_combo"),
        help="Hotkey combination, e.g.: <ctrl>+<alt>+a",
    )
    parser.add_argument(
        "-t",
        "--max-time",
        type=int,
        default=config.get("max_time", 300),
        help="Maximum recording duration (seconds), default: 300",
    )
    parser.add_argument(
        "-l",
        "--language",
        type=str,
        default=config.get("language"),
        help="Language code, e.g.: zh, en, ja",
    )
    parser.add_argument(
        "--initial-prompt",
        type=str,
        default=config.get("initial_prompt"),
        help="Initial prompt text",
    )
    parser.add_argument(
        "--streaming",
        action="store_true",
        default=config.get("streaming", False),
        help="Enable streaming output mode",
    )
    parser.add_argument(
        "--zh-convert",
        type=str,
        default=config.get("zh_convert", "t2s"),
        choices=["none", "t2s", "s2t"],
        help="Chinese conversion: t2s(traditional to simplified), s2t(simplified to traditional), none(disable)",
    )
    parser.add_argument(
        "--audio-device",
        type=int,
        default=config.get("audio_device"),
        help="Audio output device ID (use sounddevice.query_devices() to list)",
    )
    parser.add_argument(
        "--enable-beep",
        action="store_true",
        default=config.get("enable_beep", True),
        help="Enable beep sounds",
    )
    parser.add_argument(
        "--list-audio-devices",
        action="store_true",
        help="List available audio devices and exit",
    )

    args = parser.parse_args()
    return args


class States(enum.Enum):
    READY = 1
    RECORDING = 2
    TRANSCRIBING = 3
    REPLAYING = 4


transitions = [
    {"trigger": "start_recording", "source": States.READY, "dest": States.RECORDING},
    {
        "trigger": "finish_recording",
        "source": States.RECORDING,
        "dest": States.TRANSCRIBING,
    },
    {
        "trigger": "finish_transcribing",
        "source": States.TRANSCRIBING,
        "dest": States.REPLAYING,
    },
    {"trigger": "finish_replaying", "source": States.REPLAYING, "dest": States.READY},
    {"trigger": "finish_streaming", "source": States.RECORDING, "dest": States.READY},
]


class App:
    """Client application"""

    def __init__(self, args):
        m = Machine(
            states=States,
            transitions=transitions,
            send_event=True,
            ignore_invalid_triggers=True,
            initial=States.READY,
        )

        self.m = m
        self.args = args
        self.enable_beep = args.enable_beep

        # Set audio output device if specified
        if platform.system() != "Windows" and args.audio_device is not None:
            try:
                import sounddevice
                set_audio_device(args.audio_device)
                device_info = sounddevice.query_devices(args.audio_device)
                print(f"Using audio device {args.audio_device}: {device_info['name']}")
            except Exception as e:
                print(f"Warning: Failed to set audio device {args.audio_device}: {e}")

        # Set initial prompt
        initial_prompt = args.initial_prompt
        if initial_prompt is None and args.language == "zh":
            initial_prompt = "以下是普通话的句子。"
            print("Using default Chinese initial prompt to improve punctuation")

        streaming = args.streaming
        if streaming:
            print("Streaming mode enabled - will input text in real-time!")

        # Initialize transcription client (connect to server)
        self.transcriber = SpeechTranscriberClient(
            m.finish_transcribing,
            args.server_url,
            args.language,
            initial_prompt,
            streaming,
        )

        # Initialize Chinese converter
        converter = None
        if args.language == "zh" and args.zh_convert != "none":
            if OpenCC is None:
                print(
                    "OpenCC not installed. Install 'opencc-python-reimplemented' to enable Chinese conversion."
                )
            else:
                try:
                    converter = OpenCC(args.zh_convert)
                    print(f"Chinese conversion enabled: {args.zh_convert}")
                except Exception as e:
                    print(f"OpenCC initialization failed ('{args.zh_convert}'): {e}")

        self.replayer = KeyboardReplayer(m.finish_replaying, converter=converter)

        # Initialize recorder
        if streaming:

            def streaming_transcribe_callback(audio):
                """Real-time transcription callback during recording"""
                thread = threading.Thread(
                    target=self.transcriber.transcribe,
                    args=(type("Event", (), {"kwargs": {"audio": audio}})(),),
                )
                thread.daemon = True
                thread.start()

            self.recorder = Recorder(
                m.finish_streaming, streaming_callback=streaming_transcribe_callback
            )
        else:
            self.recorder = Recorder(m.finish_recording)

        self.timer = None

        m.on_enter_RECORDING(self._on_start_recording)
        m.on_exit_RECORDING(self._on_stop_recording)
        m.on_enter_TRANSCRIBING(self.transcriber.transcribe)
        m.on_enter_REPLAYING(self.replayer.replay)

        # Load sound effects
        assets_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "assets")
        self.SOUND_EFFECTS = {
            "start_recording": loadwav(os.path.join(assets_dir, "bo.wav")),
            "finish_recording": loadwav(os.path.join(assets_dir, "click.wav")),
        }

    def _on_start_recording(self, event):
        """Called when recording starts"""
        self.recorder.start()

    def _on_stop_recording(self, event):
        """Called when recording stops"""
        pass

    def beep(self, k, wait=True):
        if self.enable_beep:
            try:
                playsound(self.SOUND_EFFECTS[k], wait=wait)
            except Exception as e:
                print(f"Warning: Failed to play beep sound: {e}")

    def start(self):
        if self.m.is_READY():
            self.beep("start_recording")
            if self.args.max_time:
                self.timer = threading.Timer(self.args.max_time, self.timer_stop)
                self.timer.start()
            self.m.start_recording()
            return True

    def stop(self):
        if self.m.is_RECORDING():
            self.recorder.stop()
            if self.timer is not None:
                self.timer.cancel()
            self.beep("finish_recording", wait=False)
            return True

    def timer_stop(self):
        print("Timer stopped")
        self.stop()

    def toggle(self):
        return self.start() or self.stop()

    def run(self):
        """Run the application"""

        def normalize_key_names(keyseqs, parse=False):
            k = (
                keyseqs.replace("<win>", "<cmd>")
                .replace("<win_r>", "<cmd_r>")
                .replace("<win_l>", "<cmd_l>")
                .replace("<super>", "<cmd>")
                .replace("<super_r>", "<cmd_r>")
                .replace("<super_l>", "<cmd_l>")
            )
            if parse:
                k = keyboard.HotKey.parse(k)[0]
            print("Using key:", k)
            return k

        key = self.args.key_combo or "<alt>"
        keylistener = KeyListener(self.toggle, normalize_key_names(key))
        self.m.on_enter_READY(
            lambda *_: print("Press", key, "to start/stop recording.")
        )

        self.m.to_READY()
        keylistener.run()


if __name__ == "__main__":
    args = parse_args()

    # List audio devices if requested
    if args.list_audio_devices:
        if platform.system() == "Windows":
            print("Audio device listing is not supported on Windows")
        else:
            import sounddevice as sd
            print("=== Available Audio Devices ===")
            devices = sd.query_devices()
            for i, device in enumerate(devices):
                if device['max_output_channels'] > 0:
                    marker = " (default)" if i == sd.default.device[1] else ""
                    print(f"{i}: {device['name']} - {device['max_output_channels']} output channels{marker}")
        exit(0)

    App(args).run()
