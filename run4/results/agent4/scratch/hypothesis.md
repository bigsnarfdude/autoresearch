# Current Hypothesis

## Experiment 2: Depth 10, matrix_lr=0.06, weight_decay=0.05
Previous runs showed depth reduction AND weight_decay=0.05 were wins. But with only 183 steps at depth=8,
maybe deeper models (more capacity) can learn more per step. Also:
- matrix_lr=0.04 is default, 0.08 was too aggressive for >200 steps. Try 0.06 as compromise.
- weight_decay=0.05 was confirmed good in previous runs.
- depth=10 (max allowed) with ASPECT_RATIO=64 → dim=640, 5 heads at HEAD_DIM=128
  That's more params but ~same VRAM (batch is the bottleneck).

