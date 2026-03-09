# Predictions

## Experiment 1: Baseline (default config, depth=8)
- Predicted val_bpb: ~1.130-1.140 (concurrent contention)
- Predicted steps: ~200-220
- ACTUAL: 1.179524, 183 steps (worse than predicted - more contention than expected)

## Experiment 2: Depth 10, matrix_lr=0.06, weight_decay=0.05
- Predicted val_bpb: ~1.165-1.175
- ACTUAL: 1.155614, 188 steps (better than predicted!)

## Experiment 3: Depth 10 + RoPE base 200K + weight_decay=0.05
- Predicted val_bpb: ~1.095-1.110 (combining depth+RoPE, two biggest wins)
- Predicted steps: ~180-190
