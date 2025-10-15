#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Audio device testing script
Tests all available audio output devices to find the working one
"""

import soundfile as sf
import sounddevice as sd
import os
import time
import sys

def main():
    # Get project root directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    assets_dir = os.path.join(project_root, "assets")
    bo_file = os.path.join(assets_dir, "bo.wav")

    if not os.path.exists(bo_file):
        print(f"Error: Audio file not found: {bo_file}")
        return 1

    # Load audio file
    print("Loading test audio file...")
    data, fs = sf.read(bo_file, dtype='float32')
    print(f"✓ Loaded {bo_file} ({fs} Hz)")

    # List all devices
    print("\n=== Available Audio Output Devices ===")
    devices = sd.query_devices()
    output_devices = []

    for i, device in enumerate(devices):
        if device['max_output_channels'] > 0:
            output_devices.append(i)
            default_marker = " (default)" if i == sd.default.device[1] else ""
            print(f"  {i}: {device['name']} - {device['max_output_channels']} channels{default_marker}")

    if not output_devices:
        print("No output devices found!")
        return 1

    # Test each device
    print("\n=== Testing Devices ===")
    print("Listen for the beep sound from each device.\n")

    for device_id in output_devices:
        device = devices[device_id]
        print(f"\n{'='*60}")
        print(f"Testing device {device_id}: {device['name']}")
        print(f"{'='*60}")

        try:
            print("Playing beep sound...")
            sd.play(data, fs, device=device_id)

            # Wait for playback to finish
            print("(waiting 3 seconds...)")
            time.sleep(3)
            sd.stop()

            # Clear any buffered input
            if sys.stdin.isatty():
                import termios
                termios.tcflush(sys.stdin, termios.TCIOFLUSH)

            # Ask user for feedback
            while True:
                try:
                    response = input("\nDid you hear the beep sound? (y/n/r=replay): ").strip().lower()

                    if response == 'y':
                        print(f"\n{'*'*60}")
                        print(f"✓ Success! Device {device_id} works!")
                        print(f"{'*'*60}")
                        print(f"\nDevice name: {device['name']}")
                        print(f"Device ID: {device_id}")
                        print(f"\nTo use this device, you have 2 options:")
                        print(f"\n1. Edit config/client_config.json and set:")
                        print(f'   "audio_device": {device_id}')
                        print(f"\n2. Run client with command line option:")
                        print(f"   python3 client/client.py --audio-device {device_id}")
                        return 0

                    elif response == 'r':
                        print("Replaying...")
                        sd.play(data, fs, device=device_id)
                        time.sleep(3)
                        sd.stop()
                        continue

                    elif response == 'n':
                        print("Moving to next device...")
                        break

                    else:
                        print("Please enter 'y' (yes), 'n' (no), or 'r' (replay)")

                except (EOFError, KeyboardInterrupt):
                    print("\n\nTest interrupted by user.")
                    return 1

        except Exception as e:
            print(f"✗ Error testing device {device_id}: {e}")
            import traceback
            traceback.print_exc()
            continue

    # No working device found
    print("\n" + "="*60)
    print("No working audio device found.")
    print("="*60)
    print("\nYou can disable beep sounds by editing config/client_config.json:")
    print('  "enable_beep": false')
    return 1

if __name__ == "__main__":
    sys.exit(main())
