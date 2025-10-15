#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
音频工具模块 - 自动检测和配置采样率
"""

import platform
import pyaudio
import sounddevice
import threading
import time
import os
import sys
from typing import List, Optional, Tuple
import contextlib
import functools

def suppress_stderr(func):
    """装饰器：抑制函数执行期间的stderr输出"""
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        with SuppressStderr():
            return func(*args, **kwargs)
    return wrapper

class SuppressStderr:
    """临时抑制stderr输出的上下文管理器"""
    def __init__(self):
        self.original_stderr = None
        self.original_stderr_fd = None

    def __enter__(self):
        # 保存原始stderr
        self.original_stderr = sys.stderr
        self.original_stderr_fd = sys.stderr.fileno()

        # 重定向stderr到/devnull
        sys.stderr.flush()
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, self.original_stderr_fd)
        os.close(devnull)

        # 同时替换sys.stderr对象
        sys.stderr = open(os.devnull, 'w')
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        # 恢复原始stderr
        sys.stderr.flush()
        sys.stderr.close()

        # 恢复文件描述符
        if self.original_stderr_fd:
            sys.stderr = self.original_stderr
            os.dup2(self.original_stderr_fd, sys.stderr.fileno())

class AudioRateDetector:
    """音频采样率检测器"""

    # 常见采样率列表（按优先级排序）
    COMMON_SAMPLE_RATES = [
        44100,  # CD质量
        48000,  # DVD质量
        22050,  # VoIP常用
        16000,  # 语音识别常用
        8000,   # 电话质量
        96000,  # 高质量音频
        192000  # 专业音频
    ]

    def __init__(self):
        self.system = platform.system()
        self._cache = {}

    @suppress_stderr
    def get_supported_input_rates(self, device_index: Optional[int] = None) -> List[int]:
        """获取支持的输入采样率列表"""
        cache_key = f"input_{device_index}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        supported_rates = []

        try:
            p = pyaudio.PyAudio()

            # 获取设备信息
            if device_index is None:
                device_index = p.get_default_input_device_info()['index']

            device_info = p.get_device_info_by_index(device_index)
            print(f"检测音频设备: {device_info['name']}")

            # 测试每个采样率
            for rate in self.COMMON_SAMPLE_RATES:
                try:
                    # 尝试创建音频流来测试采样率支持
                    test_stream = p.open(
                        format=pyaudio.paInt16,
                        channels=1,
                        rate=rate,
                        frames_per_buffer=1024,
                        input=True,
                        input_device_index=device_index
                    )
                    test_stream.close()
                    supported_rates.append(rate)
                    print(f"✓ 支持采样率: {rate} Hz")
                except Exception:
                    # 不支持的采样率不打印详细错误信息，避免混淆
                    continue

            p.terminate()

        except Exception as e:
            print(f"检测采样率时出错: {e}")
            # 返回最基本的采样率作为后备
            supported_rates = [16000, 44100]

        self._cache[cache_key] = supported_rates
        return supported_rates

    @suppress_stderr
    def get_supported_output_rates(self, device_index: Optional[int] = None) -> List[int]:
        """获取支持的输出采样率列表"""
        cache_key = f"output_{device_index}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        supported_rates = []

        try:
            p = pyaudio.PyAudio()

            # 获取设备信息
            if device_index is None:
                device_index = p.get_default_output_device_info()['index']

            device_info = p.get_device_info_by_index(device_index)
            print(f"检测音频输出设备: {device_info['name']}")

            # 测试每个采样率
            for rate in self.COMMON_SAMPLE_RATES:
                # 抑制PortAudio的错误输出
                with SuppressStderr():
                    try:
                        # 尝试创建音频流来测试采样率支持
                        test_stream = p.open(
                            format=pyaudio.paInt16,
                            channels=1,
                            rate=rate,
                            frames_per_buffer=1024,
                            output=True,
                            output_device_index=device_index
                        )
                        test_stream.close()
                        supported_rates.append(rate)
                        print(f"✓ 输出支持采样率: {rate} Hz")
                    except Exception:
                        # 不支持的采样率不打印详细错误信息，避免混淆
                        continue

            p.terminate()

        except Exception as e:
            print(f"检测输出采样率时出错: {e}")
            supported_rates = [44100, 48000]

        self._cache[cache_key] = supported_rates
        return supported_rates

    def get_optimal_rate(self,
                        input_rates: List[int],
                        output_rates: List[int],
                        preferred_rate: Optional[int] = None) -> int:
        """
        获取输入输出的最佳采样率

        Args:
            input_rates: 支持的输入采样率列表
            output_rates: 支持的输出采样率列表
            preferred_rate: 首选采样率

        Returns:
            最佳采样率
        """
        # 如果有首选采样率且输入输出都支持，则使用首选采样率
        if preferred_rate and preferred_rate in input_rates and preferred_rate in output_rates:
            return preferred_rate

        # 找到输入输出都支持的采样率，按优先级排序
        common_rates = [rate for rate in self.COMMON_SAMPLE_RATES
                       if rate in input_rates and rate in output_rates]

        if common_rates:
            return common_rates[0]

        # 如果没有共同的采样率，优先保证输入（录音功能）
        if input_rates:
            return input_rates[0]

        # 最后的后备选择
        return 16000

    def auto_detect_optimal_rate(self,
                                input_device: Optional[int] = None,
                                output_device: Optional[int] = None,
                                preferred_input_rate: int = 16000,
                                preferred_output_rate: int = 44100) -> Tuple[int, int]:
        """
        自动检测最佳的输入和输出采样率

        Returns:
            (最佳输入采样率, 最佳输出采样率)
        """
        print("正在自动检测最佳音频采样率...")

        # 检测支持的输入采样率
        input_rates = self.get_supported_input_rates(input_device)
        if not input_rates:
            input_rates = [preferred_input_rate]
            print(f"警告: 无法检测输入采样率，使用默认值 {preferred_input_rate} Hz")

        # 检测支持的输出采样率
        output_rates = self.get_supported_output_rates(output_device)
        if not output_rates:
            output_rates = [preferred_output_rate]
            print(f"警告: 无法检测输出采样率，使用默认值 {preferred_output_rate} Hz")

        # 选择最佳输入采样率（优先考虑语音识别）
        if preferred_input_rate in input_rates:
            optimal_input_rate = preferred_input_rate
        else:
            # 语音识别优先选择较低的采样率
            speech_rates = [rate for rate in [16000, 22050, 8000] if rate in input_rates]
            if speech_rates:
                optimal_input_rate = speech_rates[0]
            else:
                optimal_input_rate = input_rates[0]

        # 选择最佳输出采样率（优先考虑音质）
        if preferred_output_rate in output_rates:
            optimal_output_rate = preferred_output_rate
        else:
            # 播放优先选择较高的采样率
            quality_rates = [rate for rate in [48000, 44100, 96000] if rate in output_rates]
            if quality_rates:
                optimal_output_rate = quality_rates[0]
            else:
                optimal_output_rate = output_rates[0]

        print(f"自动检测结果:")
        print(f"  最佳输入采样率: {optimal_input_rate} Hz")
        print(f"  最佳输出采样率: {optimal_output_rate} Hz")

        return optimal_input_rate, optimal_output_rate


class AudioConfigManager:
    """音频配置管理器"""

    def __init__(self):
        self.detector = AudioRateDetector()
        self._optimal_input_rate = None
        self._optimal_output_rate = None

    def initialize(self,
                  input_device: Optional[int] = None,
                  output_device: Optional[int] = None,
                  preferred_input_rate: int = 16000,
                  preferred_output_rate: int = 44100) -> Tuple[int, int]:
        """
        初始化音频配置，自动检测最佳采样率

        Returns:
            (最佳输入采样率, 最佳输出采样率)
        """
        self._optimal_input_rate, self._optimal_output_rate = self.detector.auto_detect_optimal_rate(
            input_device=input_device,
            output_device=output_device,
            preferred_input_rate=preferred_input_rate,
            preferred_output_rate=preferred_output_rate
        )

        # 在Linux系统下设置sounddevice默认采样率
        if platform.system() != "Windows":
            try:
                sounddevice.default.samplerate = self._optimal_output_rate
                print(f"设置sounddevice默认采样率为: {self._optimal_output_rate} Hz")
            except Exception as e:
                print(f"设置sounddevice默认采样率失败: {e}")

        return self._optimal_input_rate, self._optimal_output_rate

    def get_optimal_input_rate(self) -> int:
        """获取最佳输入采样率"""
        if self._optimal_input_rate is None:
            self.initialize()
        return self._optimal_input_rate

    def get_optimal_output_rate(self) -> int:
        """获取最佳输出采样率"""
        if self._optimal_output_rate is None:
            self.initialize()
        return self._optimal_output_rate

    @suppress_stderr
    def test_audio_devices(self, input_device: Optional[int] = None, output_device: Optional[int] = None) -> bool:
        """测试音频设备是否正常工作"""
        print("正在测试音频设备...")

        try:
            p = pyaudio.PyAudio()

            # 测试输入设备
            if input_device is None:
                input_device = p.get_default_input_device_info()['index']

            # 使用已检测的最佳输入采样率
            input_rate = self._optimal_input_rate or 16000

            # 抑制错误信息进行测试
            with SuppressStderr():
                input_stream = p.open(
                    format=pyaudio.paInt16,
                    channels=1,
                    rate=input_rate,
                    frames_per_buffer=1024,
                    input=True,
                    input_device_index=input_device
                )
                input_stream.close()

            print("✓ 输入设备测试成功")

            # 测试输出设备
            if output_device is None:
                output_device = p.get_default_output_device_info()['index']

            # 使用已检测的最佳输出采样率
            output_rate = self._optimal_output_rate or 44100

            # 抑制错误信息进行测试
            with SuppressStderr():
                output_stream = p.open(
                    format=pyaudio.paInt16,
                    channels=1,
                    rate=output_rate,
                    frames_per_buffer=1024,
                    output=True,
                    output_device_index=output_device
                )
                output_stream.close()

            print("✓ 输出设备测试成功")

            p.terminate()
            print("✓ 所有音频设备测试通过")
            return True

        except Exception as e:
            print(f"✗ 音频设备测试失败: {e}")
            return False


# 全局配置管理器实例
_audio_config_manager = None

def get_audio_config_manager() -> AudioConfigManager:
    """获取全局音频配置管理器实例"""
    global _audio_config_manager
    if _audio_config_manager is None:
        _audio_config_manager = AudioConfigManager()
    return _audio_config_manager

def initialize_audio_config(input_device: Optional[int] = None,
                          output_device: Optional[int] = None,
                          preferred_input_rate: int = 16000,
                          preferred_output_rate: int = 44100) -> Tuple[int, int]:
    """
    初始化音频配置（便捷函数）

    Returns:
        (最佳输入采样率, 最佳输出采样率)
    """
    manager = get_audio_config_manager()
    return manager.initialize(
        input_device=input_device,
        output_device=output_device,
        preferred_input_rate=preferred_input_rate,
        preferred_output_rate=preferred_output_rate
    )