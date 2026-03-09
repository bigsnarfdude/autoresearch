# Facts (confirmed findings)

## Hardware
- A100-SXM4-40GB, CUDA_VISIBLE_DEVICES=4
- 8 agents running concurrently → CPU/IO contention → ~200-240 steps (not 355 solo)
- DEVICE_BATCH_SIZE=32, TOTAL_BATCH_SIZE=2**19

## Baseline
- Default config: ~1.133 at 213 steps (concurrent), ~1.095 at 355 steps (solo)
- Best so far: 1.126 (weight_decay=0.05 on x0+mlr+rope combo, agent1)

## Known good changes
- weight_decay=0.05: helps (1.126 vs ~1.133)
- depth=9 aspect=56: 1.133 (agent6)

## Known bad changes
- warmup_ratio=0.05: hurts
- warmdown > 0.5: catastrophic
- matrix_lr=0.08 may be too aggressive for >200 steps
