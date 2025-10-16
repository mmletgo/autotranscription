# PyAudio Installation Guide for Windows

## Overview

PyAudio is required for the AutoTranscription client to capture audio input. This guide provides multiple methods to install PyAudio on Windows.

## Problem Background

The `pipwin` tool previously used in the installation script is no longer maintained and fails with an `AttributeError` when trying to scrape package information from its repository.

## Installation Methods

### Method 1: Automated Installation (Recommended)

The installation script now includes an automated PyAudio installer that tries multiple approaches:

```bash
scripts\windows\manage.bat install
```

The installer will:
1. Try installing from PyPI (works for Python 3.11+)
2. Download pre-compiled wheel from GitHub releases
3. Provide manual installation instructions if automatic methods fail

### Method 2: Conda Installation (Most Reliable)

If the automated installation fails, use conda-forge:

```bash
# Activate the environment
conda activate autotranscription

# Install PyAudio from conda-forge
conda install -c conda-forge pyaudio
```

This method is highly reliable and handles all dependencies automatically.

### Method 3: Manual Wheel Installation

Download the appropriate pre-compiled wheel file:

1. **For Python 3.10 (64-bit)**:
   ```bash
   # Visit: https://github.com/intxcc/pyaudio_portaudio/releases
   # Download: PyAudio-0.2.14-cp310-cp310-win_amd64.whl
   # Install:
   pip install PyAudio-0.2.14-cp310-cp310-win_amd64.whl
   ```

2. **For Python 3.11 (64-bit)**:
   ```bash
   # Download: PyAudio-0.2.14-cp311-cp311-win_amd64.whl
   pip install PyAudio-0.2.14-cp311-cp311-win_amd64.whl
   ```

3. **For Python 3.12 (64-bit)**:
   ```bash
   # Download: PyAudio-0.2.14-cp312-cp312-win_amd64.whl
   pip install PyAudio-0.2.14-cp312-cp312-win_amd64.whl
   ```

### Method 4: Build from Source (Advanced)

For advanced users who want to build from source:

1. Install Microsoft Visual C++ Build Tools:
   - Download from: https://visualstudio.microsoft.com/downloads/
   - Select "Desktop development with C++" workload

2. Download and build PortAudio library

3. Install PyAudio:
   ```bash
   pip install pyaudio
   ```

## Verification

After installation, verify PyAudio is working:

```bash
# Activate environment
conda activate autotranscription

# Test import
python -c "import pyaudio; print('PyAudio version:', pyaudio.__version__)"
```

## Troubleshooting

### Error: "No module named 'pyaudio'"

This means PyAudio is not installed. Try Method 2 (conda installation).

### Error: "Microsoft Visual C++ 14.0 or greater is required"

This occurs when pip tries to build from source. Use Method 2 (conda) or Method 3 (pre-compiled wheel) instead.

### Error: "Could not find a version that satisfies the requirement PyAudio"

Your Python version may not have pre-compiled wheels available. Use Method 2 (conda installation).

## New Installation Script Features

The updated installation process:

1. **Removes pipwin dependency**: No longer uses the outdated pipwin tool
2. **Multi-method fallback**: Tries pip, then downloads wheel, then provides instructions
3. **Non-blocking**: PyAudio installation failure won't stop the entire installation
4. **Better error messages**: Provides clear instructions for manual installation
5. **Verification improvements**: Separately checks PyAudio import to provide targeted guidance

## Script Files Modified

- `scripts/windows/install_deps.bat`: Updated PyAudio installation logic
- `scripts/windows/install_pyaudio.bat`: New dedicated PyAudio installer
- Verification step now handles PyAudio separately from core dependencies

## Impact on System

- The server component does NOT require PyAudio (only client needs it)
- If PyAudio installation fails, you can still:
  - Run the server for transcription services
  - Use the system without client audio recording
  - Install PyAudio manually later when needed

## References

- PyAudio Official: http://people.csail.mit.edu/hubert/pyaudio/
- Pre-compiled Windows Wheels: https://github.com/intxcc/pyaudio_portaudio/releases
- Conda-forge PyAudio: https://anaconda.org/conda-forge/pyaudio
