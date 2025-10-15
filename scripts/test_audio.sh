#!/bin/bash
# Audio device testing script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Detect conda installation
if [ -d "$HOME/anaconda3" ]; then
    CONDA_PATH="$HOME/anaconda3"
elif [ -d "$HOME/miniconda3" ]; then
    CONDA_PATH="$HOME/miniconda3"
else
    echo "Error: Neither anaconda3 nor miniconda3 found in home directory"
    exit 1
fi

# Activate conda environment
source "$CONDA_PATH/etc/profile.d/conda.sh"
conda activate autotranscription

# Run the Python test script
python3 "$SCRIPT_DIR/test_audio_devices.py"
