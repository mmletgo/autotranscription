#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
自动测试所有麦克风设备
Automatically test all microphone devices
"""

import pyaudio
import numpy as np
import sys

def test_device(device_index, device_name, duration=3):
    """测试单个设备"""
    p = pyaudio.PyAudio()

    print(f"\n{'='*60}")
    print(f"测试设备 {device_index}: {device_name}")
    print(f"{'='*60}")

    try:
        stream = p.open(
            format=pyaudio.paInt16,
            channels=1,
            rate=16000,
            frames_per_buffer=1024,
            input=True,
            input_device_index=device_index
        )

        print(f"录音 {duration} 秒,请说话...")

        frames = []
        for i in range(0, int(16000 / 1024 * duration)):
            try:
                data = stream.read(1024, exception_on_overflow=False)
                frames.append(data)

                # 实时显示音量
                audio_data = np.frombuffer(data, dtype=np.int16)
                volume = np.abs(audio_data).mean()
                bars = min(int(volume / 100), 50)
                print(f"\r音量: {'█' * bars}{' ' * (50 - bars)} {volume:.0f}  ", end='', flush=True)
            except Exception as e:
                print(f"\n读取错误: {e}")
                break

        print()  # 换行

        stream.stop_stream()
        stream.close()
        p.terminate()

        # 分析结果
        if frames:
            audio_data = np.frombuffer(b"".join(frames), dtype=np.int16)
            audio_fp32 = audio_data.astype(np.float32) / 32768.0
            avg_energy = np.abs(audio_fp32).mean()
            max_value = np.abs(audio_fp32).max()

            print(f"平均能量: {avg_energy:.6f}")
            print(f"最大值: {max_value:.6f}")

            if avg_energy > 0.01:
                print("✓ 该设备工作正常!")
                return True
            elif avg_energy > 0.001:
                print("⚠ 设备工作但音量很低")
                return False
            else:
                print("✗ 设备无声音输入")
                return False
        else:
            print("✗ 无法录音")
            return False

    except Exception as e:
        print(f"✗ 打开设备失败: {e}")
        p.terminate()
        return False

def main():
    """主函数"""
    p = pyaudio.PyAudio()

    print("="*60)
    print("自动测试所有麦克风设备")
    print("="*60)

    # 找到所有输入设备
    input_devices = []
    for i in range(p.get_device_count()):
        device_info = p.get_device_info_by_index(i)
        if device_info['maxInputChannels'] > 0:
            input_devices.append((i, device_info))

    p.terminate()

    if not input_devices:
        print("✗ 未找到任何输入设备!")
        return

    print(f"\n找到 {len(input_devices)} 个输入设备\n")

    # 测试每个设备
    working_devices = []
    for idx, device_info in input_devices:
        result = test_device(idx, device_info['name'], duration=3)
        if result:
            working_devices.append((idx, device_info['name']))
        print()  # 空行分隔

    # 总结
    print("="*60)
    print("测试总结")
    print("="*60)

    if working_devices:
        print(f"\n✓ 找到 {len(working_devices)} 个工作正常的设备:\n")
        for idx, name in working_devices:
            print(f"  设备 {idx}: {name}")

        if len(working_devices) == 1:
            print(f"\n建议: 客户端将自动使用设备 {working_devices[0][0]}")
        else:
            print(f"\n建议: 在 config/client_config.json 中设置:")
            print(f'  "input_device_index": {working_devices[0][0]}')
    else:
        print("\n✗ 没有找到工作正常的麦克风设备!")
        print("\n请检查:")
        print("  1. Windows隐私设置是否允许麦克风访问")
        print("  2. 麦克风是否被禁用或静音")
        print("  3. 麦克风驱动是否正常")
        print("\n打开Windows设置:")
        print("  设置 → 隐私和安全性 → 麦克风")
        print("  确保'允许应用访问麦克风'已开启")

if __name__ == "__main__":
    main()
