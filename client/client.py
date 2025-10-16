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

# 导入音频工具模块
from audio_utils import get_audio_config_manager, initialize_audio_config

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
    import numpy as np
    from scipy import signal  # 用于音频重采样

    _audio_device = None  # Will be set from config
    _audio_output_rate = None  # Will be set by audio config manager

    def resample_audio(data, orig_sr, target_sr):
        """音频重采样函数"""
        if orig_sr == target_sr:
            return data

        # 计算重采样比例
        resample_ratio = target_sr / orig_sr
        num_samples = int(len(data) * resample_ratio)

        # 使用scipy进行重采样
        resampled_data = signal.resample(data, num_samples)
        return resampled_data.astype(data.dtype)

    def playsound(s, wait=True):
        # s is a tuple of (data, samplerate)
        if isinstance(s, tuple):
            data, fs = s

            # 如果音频采样率与输出采样率不匹配，进行重采样
            if _audio_output_rate and fs != _audio_output_rate:
                print(f"音频重采样: {fs}Hz -> {_audio_output_rate}Hz")
                data = resample_audio(data, fs, _audio_output_rate)
                fs = _audio_output_rate

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

    def set_audio_output_rate(rate):
        """设置音频输出采样率"""
        global _audio_output_rate
        _audio_output_rate = rate
        try:
            sounddevice.default.samplerate = rate
        except Exception as e:
            print(f"设置默认输出采样率失败: {e}")


class SpeechTranscriberClient:
    """Speech transcription client - calls remote API"""

    def __init__(
        self,
        callback,
        server_url,
        language=None,
        initial_prompt=None,
        streaming=False,
        replayer=None,
    ):
        self.callback = callback
        self.server_url = server_url.rstrip("/")
        self.language = language
        self.initial_prompt = initial_prompt
        self.streaming = streaming
        self.replayer = replayer  # For live streaming output
        self.session = requests.Session()

        # For deduplication of streaming results
        self.last_transcribed_text = ""
        self.cumulative_text = ""

        # Hallucination patterns to filter out
        self.hallucination_patterns = [
            "字幕",
            "志愿者",
            "翻译",
            "制作",
            "感谢观看",
            "订阅",
            "点赞",
            "关注",
            "频道",
            "转载",
            "请不要",
            "谢谢",
            "www.",
            "http",
            ".com",
            "下载",
            "更多",
            "音乐",
            "MV",
            "official",
        ]

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
                            seg_text = seg_data["text"].strip()

                            # Skip hallucination segments in final transcription
                            if self.streaming and self._is_hallucination(seg_text):
                                print(
                                    f"[Filter] Skipping hallucination segment: {seg_text}"
                                )
                                continue

                            segment = type(
                                "Segment",
                                (),
                                {
                                    "start": seg_data["start"],
                                    "end": seg_data["end"],
                                    "text": seg_text,
                                },
                            )()
                            segments.append(segment)

                        print(
                            f"Detected language: {result.get('language')} "
                            f"(probability: {result.get('language_probability', 0):.2f})"
                        )

                        # Handle streaming or non-streaming output
                        if self.streaming:
                            # Pass all segments with streaming flag
                            # The replayer will handle outputting them one by one
                            self.callback(segments=segments, streaming=True)
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

    def transcribe_chunk_live(self, audio):
        """Transcribe audio chunk during recording (live streaming mode)"""
        if not self.streaming or not self.replayer:
            return

        # Check if audio has sufficient energy (not silence)
        audio_energy = np.abs(audio).mean()
        if audio_energy < 0.01:  # Very low energy, likely silence
            print("[Live] Skipping chunk (silence detected)")
            return

        print("[Live] Transcribing audio chunk...")

        try:
            # Prepare request data
            request_data = {
                "audio_data": audio.tolist(),
                "sample_rate": 16000,
                "streaming": False,  # Server doesn't need to know about client streaming
            }

            if self.language:
                request_data["language"] = self.language

            # Use cumulative text as context for better accuracy
            if self.cumulative_text:
                request_data["initial_prompt"] = self.cumulative_text[
                    -200:
                ]  # Last 200 chars as context
            elif self.initial_prompt:
                request_data["initial_prompt"] = self.initial_prompt

            # Send request to server
            response = self.session.post(
                f"{self.server_url}/api/transcribe", json=request_data, timeout=30
            )

            if response.status_code == 200:
                result = response.json()

                if result.get("success"):
                    # Get full transcription text
                    current_text = result.get("text", "").strip()

                    if not current_text:
                        return

                    print(f"[Live] Raw result: {current_text}")

                    # Filter hallucinations
                    if self._is_hallucination(current_text):
                        print(f"[Filter] Skipping hallucination: {current_text}")
                        return

                    # Deduplicate: find new content by comparing with cumulative text
                    new_text = self._extract_new_content(current_text)

                    if new_text and not self._is_hallucination(new_text):
                        print(f"[Live] New content: {new_text}")

                        # Update cumulative text
                        self.cumulative_text = (
                            self.cumulative_text + " " + new_text
                        ).strip()

                        # Create segment for new text only
                        segment = type(
                            "Segment",
                            (),
                            {
                                "start": 0,
                                "end": 0,
                                "text": new_text,
                            },
                        )()

                        # Output new content immediately
                        fake_event = type(
                            "Event",
                            (),
                            {
                                "kwargs": {
                                    "segments": [segment],
                                    "streaming": True,
                                    "live": True,
                                }
                            },
                        )()
                        self.replayer.replay(fake_event)
                    else:
                        print("[Live] No new content (duplicate or overlap)")

        except requests.exceptions.Timeout:
            print("[Live] Transcription timeout (chunk skipped)")
        except Exception as e:
            print(f"[Live] Transcription error: {e}")

    def _is_hallucination(self, text):
        """Check if text contains common hallucination patterns"""
        if not text or len(text.strip()) < 2:
            return True

        # Check for hallucination keywords
        for pattern in self.hallucination_patterns:
            if pattern in text:
                print(
                    f"[Filter] Detected hallucination pattern: '{pattern}' in '{text}'"
                )
                return True

        # Check if text is suspiciously short after long silence
        if len(text.strip()) < 3:
            return True

        return False

    def _extract_new_content(self, current_text):
        """Extract new content by comparing with cumulative text"""
        if not self.cumulative_text:
            return current_text

        # Simple approach: check if current text starts with end of cumulative text
        # Find the longest common suffix of cumulative_text that is a prefix of current_text
        cumulative_words = self.cumulative_text.split()
        current_words = current_text.split()

        # Try to find overlap
        max_overlap = min(len(cumulative_words), len(current_words))
        overlap_length = 0

        for i in range(1, max_overlap + 1):
            # Check if last i words of cumulative match first i words of current
            if cumulative_words[-i:] == current_words[:i]:
                overlap_length = i

        # Extract new words (skip overlapping words)
        if overlap_length > 0:
            new_words = current_words[overlap_length:]
        else:
            # No overlap found - check if cumulative is substring of current
            if self.cumulative_text in current_text:
                # Current contains cumulative, extract the rest
                idx = current_text.find(self.cumulative_text)
                new_text = current_text[idx + len(self.cumulative_text) :].strip()
                return new_text
            else:
                # No clear relationship, output all
                new_words = current_words

        return " ".join(new_words).strip()


class Recorder:
    """Audio recorder"""

    def __init__(self, callback, streaming_callback=None):
        self.callback = callback
        self.streaming_callback = streaming_callback
        self.recording = False
        self.stream_interval = (
            3.0  # Increased from 1.0 to 3.0 seconds for better accuracy
        )
        self.overlap_duration = 0.5  # Keep 0.5s overlap with previous chunk for context
        # 获取音频配置管理器
        self.audio_config = get_audio_config_manager()
        # Store previous chunk for overlap
        self.previous_chunk_frames = []

    def start(self, language=None):
        print("Recording started...")
        # Reset previous chunk buffer for new recording session
        self.previous_chunk_frames = []
        thread = threading.Thread(target=self._record_impl, args=())
        thread.start()

    def stop(self):
        print("Recording stopped.")
        self.recording = False

    def _record_impl(self):
        """Internal recording implementation with error handling"""
        self.recording = True

        frames_per_buffer = 1024
        # 使用动态检测的最佳输入采样率
        sample_rate = self.audio_config.get_optimal_input_rate()
        p = None
        stream = None

        try:
            print(f"正在使用采样率: {sample_rate} Hz")
            p = pyaudio.PyAudio()

            # Get default input device info for debugging
            try:
                default_input = p.get_default_input_device_info()
                print(f"使用音频设备: {default_input['name']}")
            except Exception as e:
                print(f"Warning: Could not get default input device info: {e}")

            stream = p.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=sample_rate,
                frames_per_buffer=frames_per_buffer,
                input=True,
            )
            print("✓ 音频流成功打开")

            frames = []
            chunk_frames = []
            frames_per_chunk = int(
                sample_rate * self.stream_interval / frames_per_buffer
            )
            frames_for_overlap = int(
                sample_rate * self.overlap_duration / frames_per_buffer
            )
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
                            # Combine overlap from previous chunk with current chunk
                            combined_frames = self.previous_chunk_frames + chunk_frames
                            audio_chunk = np.frombuffer(
                                b"".join(combined_frames), dtype=np.int16
                            )
                            audio_chunk_fp32 = audio_chunk.astype(np.float32) / 32768.0

                            # Send for transcription
                            self.streaming_callback(audio=audio_chunk_fp32)

                            # Keep last frames_for_overlap frames for next chunk's context
                            self.previous_chunk_frames = (
                                chunk_frames[-frames_for_overlap:]
                                if len(chunk_frames) >= frames_for_overlap
                                else chunk_frames
                            )

                            chunk_frames = []
                            frame_count = 0
                except Exception as e:
                    print(f"Error reading audio frame: {e}")
                    break

            print(
                f"Recorded {len(frames)} frames ({len(frames) * frames_per_buffer / sample_rate:.2f}s)"
            )

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


def is_running_in_terminal():
    """Check if the program is running in a terminal (not just focused on one)"""
    if platform.system() == "Windows":
        return False

    # Check if we can access /dev/tty (the controlling terminal)
    # This works even if stdout is redirected
    try:
        # Try to open /dev/tty to check if we have a controlling terminal
        try:
            with open("/dev/tty", "r"):
                term_env = os.environ.get("TERM", "")
                if term_env and term_env not in ["dumb", ""]:
                    return True
        except (IOError, OSError):
            pass

    except Exception:
        pass

    return False


def disable_bracketed_paste():
    """Disable bracketed paste mode in terminal"""
    if platform.system() == "Windows":
        return

    try:
        # Send escape sequence directly to /dev/tty (the controlling terminal)
        # This works even if stdout is redirected
        with open("/dev/tty", "w") as tty:
            tty.write("\033[?2004l")
            tty.flush()
        time.sleep(0.2)  # Give terminal more time to process the escape sequence
    except Exception:
        pass


def enable_bracketed_paste():
    """Enable bracketed paste mode in terminal"""
    if platform.system() == "Windows":
        return

    try:
        # Send escape sequence directly to /dev/tty (the controlling terminal)
        # This works even if stdout is redirected
        time.sleep(0.05)  # Give terminal time before re-enabling
        with open("/dev/tty", "w") as tty:
            tty.write("\033[?2004h")
            tty.flush()
    except Exception:
        pass


def get_ime_state():
    """Get current input method state (fcitx or ibus)

    Returns:
        tuple: (ime_type, state) where ime_type is 'fcitx', 'ibus', or None
               and state is the current state (varies by IME type)
    """
    if platform.system() == "Windows":
        return (None, None)

    # Try fcitx first
    try:
        import subprocess

        result = subprocess.run(
            ["fcitx-remote"], capture_output=True, text=True, timeout=0.5
        )
        if result.returncode == 0:
            state = result.stdout.strip()
            return ("fcitx", state)
    except (FileNotFoundError, subprocess.SubprocessError):
        pass

    # Try ibus
    try:
        import subprocess

        result = subprocess.run(
            ["ibus", "engine"], capture_output=True, text=True, timeout=0.5
        )
        if result.returncode == 0:
            engine = result.stdout.strip()
            return ("ibus", engine)
    except (FileNotFoundError, subprocess.SubprocessError):
        pass

    return (None, None)


def disable_ime():
    """Temporarily disable input method (switch to English)

    Returns:
        tuple: (ime_type, original_state) to restore later
    """
    if platform.system() == "Windows":
        return (None, None)

    ime_type, state = get_ime_state()

    if ime_type == "fcitx":
        # fcitx-remote -c: deactivate (switch to English)
        try:
            import subprocess

            subprocess.run(["fcitx-remote", "-c"], timeout=0.5)
            return ("fcitx", state)
        except Exception:
            pass

    elif ime_type == "ibus":
        # Switch to xkb:us::eng (English keyboard)
        try:
            import subprocess

            subprocess.run(["ibus", "engine", "xkb:us::eng"], timeout=0.5)
            return ("ibus", state)
        except Exception:
            pass

    return (None, None)


def restore_ime(ime_info):
    """Restore input method to previous state

    Args:
        ime_info: tuple (ime_type, original_state) from disable_ime()
    """
    if platform.system() == "Windows":
        return

    ime_type, original_state = ime_info

    if ime_type == "fcitx" and original_state == "2":
        # Restore to active state
        try:
            import subprocess

            subprocess.run(["fcitx-remote", "-o"], timeout=0.5)
        except Exception:
            pass

    elif ime_type == "ibus" and original_state:
        # Restore to original engine
        try:
            import subprocess

            subprocess.run(["ibus", "engine", original_state], timeout=0.5)
        except Exception:
            pass


def get_active_window_class():
    """Get the class name of the currently active window

    Returns:
        str: Window class name, or None if detection fails
    """
    if platform.system() == "Windows":
        return None

    try:
        import subprocess

        # Get active window ID using xdotool
        result = subprocess.run(
            ["xdotool", "getactivewindow"], capture_output=True, text=True, timeout=0.5
        )

        if result.returncode == 0:
            window_id = result.stdout.strip()

            # Get window class using xprop
            result = subprocess.run(
                ["xprop", "-id", window_id, "WM_CLASS"],
                capture_output=True,
                text=True,
                timeout=0.5,
            )

            if result.returncode == 0:
                # Parse output like: WM_CLASS(STRING) = "gnome-terminal-server", "Gnome-terminal"
                output = result.stdout.strip()
                if "WM_CLASS" in output:
                    # Extract class names from the output
                    import re

                    matches = re.findall(r'"([^"]+)"', output)
                    if matches:
                        # Return all class names as lowercase for easier matching
                        window_classes = [m.lower() for m in matches]
                        return window_classes
    except Exception:
        pass

    return None


def is_terminal_window():
    """Check if the currently active window is a terminal emulator

    Returns:
        bool: True if active window is a terminal, False otherwise
    """
    window_classes = get_active_window_class()

    if not window_classes:
        return False

    # List of known terminal emulator class names/patterns
    # Also includes text editors with integrated terminals (VSCode, etc)
    terminal_indicators = [
        "terminal",
        "konsole",
        "xterm",
        "rxvt",
        "terminator",
        "gnome-terminal",
        "xfce4-terminal",
        "mate-terminal",
        "lxterminal",
        "tilix",
        "alacritty",
        "kitty",
        "wezterm",
        "foot",
        "qterminal",
        "deepin-terminal",
        "terminology",
        "guake",
        "tilda",
        "yakuake",
        "code",  # VSCode
        "vscode",  # VSCode alternative class name
        "vim",  # Vim/Neovim
        "nvim",  # Neovim
    ]

    # Check if any window class contains terminal indicators
    for window_class in window_classes:
        for indicator in terminal_indicators:
            if indicator in window_class:
                return True

    # Also check for specific terminal applications that might not have 'terminal' in the name
    for window_class in window_classes:
        if window_class in ["urxvt", "st", "cool-retro-term", "hyper"]:
            return True

    return False


def ensure_ime_disabled(timeout=2.0):
    """Ensure input method is disabled, with retry logic

    Args:
        timeout: Maximum time to wait for IME to be disabled (seconds)

    Returns:
        bool: True if IME was successfully disabled, False otherwise
    """
    if platform.system() == "Windows":
        return True

    import subprocess

    start_time = time.time()
    attempt = 0

    while time.time() - start_time < timeout:
        attempt += 1

        # Check fcitx state
        try:
            result = subprocess.run(
                ["fcitx-remote"], capture_output=True, text=True, timeout=0.5
            )
            if result.returncode == 0:
                state = result.stdout.strip()

                if state == "1":  # 1 = inactive (disabled)
                    return True
                elif state == "2":  # 2 = active (enabled)
                    subprocess.run(["fcitx-remote", "-c"], timeout=0.5)
                    time.sleep(0.2)  # Wait for command to take effect
                    continue
        except (FileNotFoundError, subprocess.SubprocessError):
            # fcitx not available, assume no IME interference
            return True

        time.sleep(0.1)  # Small delay before retry

    return False


class KeyboardReplayer:
    """Keyboard output handler"""

    def __init__(self, callback, converter=None):
        self.callback = callback
        self.kb = keyboard.Controller()
        self.converter = converter

    def _paste_text(self, text=None):
        """Paste text from clipboard using appropriate method

        Args:
            text: Text to paste/type. If None, pastes from clipboard.
        """
        # Auto-detect window type and choose appropriate paste method
        if platform.system() != "Windows":
            try:
                import subprocess

                # Detect if active window is a terminal
                use_terminal_paste = is_terminal_window()

                if use_terminal_paste:
                    # Use Ctrl+Shift+V for terminal windows
                    subprocess.run(
                        ["xdotool", "key", "--clearmodifiers", "ctrl+shift+v"],
                        check=True,
                        timeout=2,
                    )
                else:
                    # Use Ctrl+V for non-terminal applications
                    subprocess.run(
                        ["xdotool", "key", "--clearmodifiers", "ctrl+v"],
                        check=True,
                        timeout=2,
                    )

                time.sleep(0.15)
                return
            except (FileNotFoundError, subprocess.SubprocessError):
                pass

        # Fallback: pynput for Windows or if xdotool fails
        time.sleep(0.1)
        with self.kb.pressed(keyboard.Key.ctrl):
            self.kb.press("v")
            self.kb.release("v")
        time.sleep(0.15)

    def replay(self, event):
        segments = event.kwargs.get("segments", [])
        is_streaming = event.kwargs.get("streaming", False)
        is_final = event.kwargs.get("final", False)
        is_live = event.kwargs.get("live", False)

        if is_streaming:
            # Streaming mode: output segments one by one in real-time
            if is_live:
                # Live streaming during recording: output immediately, no callback
                self._type_segments(segments, streaming=True)
                # Don't call callback - we're still recording
            else:
                # Standard streaming mode: output all segments one by one after recording
                print("Streaming output: typing segments one by one...")
                self._type_segments(segments, streaming=True)
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

                # Paste using appropriate shortcut (Ctrl+Shift+V for terminal, Ctrl+V for others)
                self._paste_text(text=full_text)

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

                    # Paste using appropriate shortcut
                    self._paste_text(text=text)

                    time.sleep(0.05)
                    self.kb.type(" ")
                except Exception as e:
                    print(f"Error typing text segment: {e}")


class KeyListener:
    """Keyboard listener"""

    def __init__(self, callback, key):
        self.callback = callback
        self.key = key
        self.listener = None
        self.running = False

    def run(self):
        """Run keyboard listener with Ctrl+C support"""
        self.running = True
        self.listener = keyboard.GlobalHotKeys({self.key: self.callback})
        self.listener.start()

        print("Keyboard listener started. Press Ctrl+C to exit.")

        try:
            # Use a loop with sleep instead of join() to allow Ctrl+C handling
            while self.running:
                time.sleep(0.1)
        except KeyboardInterrupt:
            print("\nCtrl+C detected. Stopping...")
            self.stop()
        finally:
            if self.listener is not None and self.listener.is_alive():
                self.listener.stop()

    def stop(self):
        """Stop the keyboard listener"""
        self.running = False
        if self.listener is not None:
            self.listener.stop()


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
    parser.add_argument(
        "--test-audio-config",
        action="store_true",
        help="Test audio configuration and auto-detect optimal sample rates",
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

        # Debounce mechanism to prevent double-triggering
        self.last_toggle_time = 0
        self.debounce_interval = 0.3  # 300ms debounce window

        # 初始化音频配置 - 自动检测最佳采样率
        print("正在初始化音频配置...")
        try:
            input_rate, output_rate = initialize_audio_config(
                input_device=None,  # 使用默认输入设备
                output_device=(
                    args.audio_device if platform.system() != "Windows" else None
                ),
                preferred_input_rate=16000,  # 语音识别偏好采样率
                preferred_output_rate=44100,  # 播放偏好采样率
            )
            print(f"✓ 音频配置初始化完成: 输入={input_rate}Hz, 输出={output_rate}Hz")

            # 设置Linux系统的音频输出采样率
            if platform.system() != "Windows":
                set_audio_output_rate(output_rate)

        except Exception as e:
            print(f"⚠ 音频配置初始化失败，使用默认配置: {e}")
            print("将使用固定采样率: 输入=16000Hz, 输出=44100Hz")

        # Set audio output device if specified
        if platform.system() != "Windows" and args.audio_device is not None:
            try:
                import sounddevice

                set_audio_device(args.audio_device)
                device_info = sounddevice.query_devices(args.audio_device)
                print(f"使用音频设备 {args.audio_device}: {device_info['name']}")
            except Exception as e:
                print(f"Warning: Failed to set audio device {args.audio_device}: {e}")

        # Set initial prompt - use strong prompt to reduce hallucinations
        initial_prompt = args.initial_prompt
        if initial_prompt is None and args.language == "zh":
            # Use a prompt that discourages common hallucinations
            initial_prompt = "这是一段真实的语音对话内容。"
            print("Using anti-hallucination Chinese initial prompt")

        streaming = args.streaming
        if streaming:
            print("Streaming mode enabled - will input text in real-time!")

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

        # Initialize replayer first (needed by transcriber for live streaming)
        self.replayer = KeyboardReplayer(m.finish_replaying, converter=converter)

        # Initialize transcription client (connect to server)
        self.transcriber = SpeechTranscriberClient(
            m.finish_transcribing,
            args.server_url,
            args.language,
            initial_prompt,
            streaming,
            replayer=self.replayer if streaming else None,
        )

        # Initialize recorder with live streaming support
        if streaming:

            def live_transcribe_callback(audio):
                """Live transcription callback during recording"""
                # Run in separate thread to avoid blocking recording
                thread = threading.Thread(
                    target=self.transcriber.transcribe_chunk_live,
                    args=(audio,),
                )
                thread.daemon = True
                thread.start()

            self.recorder = Recorder(
                m.finish_recording, streaming_callback=live_transcribe_callback
            )
            print("✓ Live streaming transcription enabled")
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
        # Reset cumulative text for new recording session
        if self.args.streaming:
            self.transcriber.cumulative_text = ""
            self.transcriber.last_transcribed_text = ""
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
            # Start state transition FIRST (before beep) to avoid delay
            if self.args.max_time:
                self.timer = threading.Timer(self.args.max_time, self.timer_stop)
                self.timer.start()
            self.m.start_recording()
            # Play beep sound after state transition (non-blocking)
            self.beep("start_recording", wait=False)
            return True
        return False

    def stop(self):
        if self.m.is_RECORDING():
            self.recorder.stop()
            if self.timer is not None:
                self.timer.cancel()
            self.beep("finish_recording", wait=False)
            return True
        return False

    def timer_stop(self):
        print("Timer stopped")
        self.stop()

    def toggle(self):
        # Debounce mechanism to prevent rapid double-triggering
        current_time = time.time()
        time_since_last = current_time - self.last_toggle_time

        if time_since_last < self.debounce_interval:
            return False

        self.last_toggle_time = current_time

        result = self.start() or self.stop()
        return result

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

    # Test audio configuration if requested
    if args.test_audio_config:
        print("=== 音频配置测试 ===")
        try:
            from audio_utils import AudioConfigManager

            config_manager = AudioConfigManager()

            # 初始化配置（包含设备测试）
            input_rate, output_rate = config_manager.initialize(
                input_device=None,
                output_device=(
                    args.audio_device if platform.system() != "Windows" else None
                ),
                preferred_input_rate=16000,
                preferred_output_rate=44100,
            )

            print(f"\n检测结果:")
            print(f"✓ 最佳输入采样率: {input_rate} Hz")
            print(f"✓ 最佳输出采样率: {output_rate} Hz")
            print("✓ 音频设备测试已在初始化过程中完成")

        except Exception as e:
            print(f"✗ 音频配置测试失败: {e}")
            import traceback

            traceback.print_exc()
        exit(0)

    # List audio devices if requested
    if args.list_audio_devices:
        if platform.system() == "Windows":
            print("Audio device listing is not supported on Windows")
        else:
            import sounddevice as sd

            print("=== Available Audio Devices ===")
            devices = sd.query_devices()
            for i, device in enumerate(devices):
                if device["max_output_channels"] > 0:
                    marker = " (default)" if i == sd.default.device[1] else ""
                    print(
                        f"{i}: {device['name']} - {device['max_output_channels']} output channels{marker}"
                    )
        exit(0)

    App(args).run()
