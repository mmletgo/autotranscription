#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试麦克风输入设备
Test microphone input devices on Windows
"""

import pyaudio
import numpy as np
import time

def list_audio_devices():
    """列出所有可用的音频设备"""
    p = pyaudio.PyAudio()

    print("=" * 60)
    print("可用的音频输入设备:")
    print("=" * 60)

    input_devices = []

    for i in range(p.get_device_count()):
        device_info = p.get_device_info_by_index(i)
        if device_info['maxInputChannels'] > 0:
            input_devices.append((i, device_info))
            print(f"\n设备 {i}:")
            print(f"  名称: {device_info['name']}")
            print(f"  输入通道数: {device_info['maxInputChannels']}")
            print(f"  默认采样率: {device_info['defaultSampleRate']:.0f} Hz")

            # 标记默认设备
            try:
                default_input = p.get_default_input_device_info()
                if default_input['index'] == i:
                    print(f"  ★ 当前默认输入设备")
            except:
                pass

    p.terminate()
    return input_devices

def test_microphone(device_index=None, duration=3):
    """测试麦克风录音"""
    p = pyaudio.PyAudio()

    # 获取设备信息
    if device_index is not None:
        device_info = p.get_device_info_by_index(device_index)
        print(f"\n测试设备 {device_index}: {device_info['name']}")
    else:
        device_info = p.get_default_input_device_info()
        device_index = device_info['index']
        print(f"\n测试默认设备: {device_info['name']}")

    sample_rate = 16000

    try:
        print(f"开始录音 {duration} 秒,请对着麦克风说话...")
        print("=" * 60)

        stream = p.open(
            format=pyaudio.paInt16,
            channels=1,
            rate=sample_rate,
            frames_per_buffer=1024,
            input=True,
            input_device_index=device_index
        )

        frames = []
        for i in range(0, int(sample_rate / 1024 * duration)):
            data = stream.read(1024, exception_on_overflow=False)
            frames.append(data)

            # 实时显示音量
            audio_data = np.frombuffer(data, dtype=np.int16)
            volume = np.abs(audio_data).mean()
            bars = int(volume / 100)
            print(f"\r音量: {'█' * bars}{' ' * (50 - bars)} {volume:.0f}", end='', flush=True)

        print("\n" + "=" * 60)

        stream.stop_stream()
        stream.close()
        p.terminate()

        # 分析录音结果
        audio_data = np.frombuffer(b"".join(frames), dtype=np.int16)
        audio_fp32 = audio_data.astype(np.float32) / 32768.0

        print(f"\n录音分析:")
        print(f"  总采样点: {len(audio_fp32)}")
        print(f"  平均能量: {np.abs(audio_fp32).mean():.6f}")
        print(f"  最大值: {np.abs(audio_fp32).max():.6f}")
        print(f"  最小值: {np.abs(audio_fp32).min():.6f}")

        if np.abs(audio_fp32).mean() < 0.001:
            print("\n⚠ 警告: 音频能量非常低,麦克风可能未工作!")
            print("  可能原因:")
            print("  1. 麦克风被禁用或静音")
            print("  2. Windows隐私设置阻止了麦克风访问")
            print("  3. 选择了错误的输入设备")
        elif np.abs(audio_fp32).mean() < 0.01:
            print("\n⚠ 警告: 音频能量较低,请靠近麦克风或提高音量")
        else:
            print("\n✓ 麦克风工作正常!")

        return audio_fp32

    except Exception as e:
        print(f"\n✗ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        p.terminate()
        return None

def main():
    """主函数"""
    print("Windows 麦克风测试工具")
    print("=" * 60)

    # 1. 列出所有设备
    devices = list_audio_devices()

    if not devices:
        print("\n✗ 未找到任何音频输入设备!")
        return

    # 2. 测试默认设备
    print("\n" + "=" * 60)
    print("1. 测试默认麦克风")
    print("=" * 60)
    test_microphone(duration=3)

    # 3. 询问是否测试其他设备
    if len(devices) > 1:
        print("\n" + "=" * 60)
        while True:
            try:
                response = input(f"\n是否测试其他设备? (输入设备编号 0-{len(devices)-1}, 或按Enter退出): ").strip()
                if not response:
                    break

                device_id = int(response)
                if 0 <= device_id < len(devices):
                    test_microphone(device_index=devices[device_id][0], duration=3)
                else:
                    print(f"无效的设备编号,请输入 0-{len(devices)-1}")
            except ValueError:
                print("请输入有效的数字")
            except KeyboardInterrupt:
                print("\n\n测试中断")
                break

    print("\n测试完成!")

if __name__ == "__main__":
    main()
