# Experiment Progress

## Current State

- **Best val_bpb**: (none yet — run baseline first)
- **Best commit**: (none)
- **Baseline val_bpb**: (not yet established)
- **Experiments run**: 0

## GPU Environment

- **GPU**: NVIDIA RTX 4070 Ti SUPER (16GB VRAM)
- **Server**: nigel.birs.ca
- **Working dir**: ~/autoresearch/
- **Run command**: `source ~/.local/bin/env && timeout 700 uv run train.py > run.log 2>&1`
- **Check results**: `grep "^val_bpb:\|^peak_vram_mb:" run.log`

## Important GPU Notes

This GPU has 16GB VRAM, NOT 80GB like H100. The default DEVICE_BATCH_SIZE=128 WILL OOM.
You MUST reduce DEVICE_BATCH_SIZE before running. Start with 32 (known to work at depth 8).
If you change model size, you may need to adjust batch size.

## Current Best Hyperparameters

(Start with defaults in train.py — run baseline first)

## Strategic Insights

(None yet — build these as you run experiments)

## Experiment History

(Empty — first run should establish the baseline)
