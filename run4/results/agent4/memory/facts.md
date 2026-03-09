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
- warmdown > 0.5: catastrophic (confirmed exp5: 1.162 vs 1.153 baseline)
- matrix_lr=0.08 may be too aggressive for >200 steps
- wd=0.05 at depth=10 causes divergence for me (exp3), but works for agent6 (more steps)
- softcap=30: hurts (agent2)
- HEAD_DIM=64: doesn't help (agent1)

## My best config
- exp8: 1.123623 — depth=10 RoPE200K init0.68 warmdown=0.4 short_window//8, 210 steps
- Stable training, no loss spikes! warmdown=0.4 is the sweet spot for ~200 steps
- Previous best exp6 (1.135, warmdown=0.3) had loss spike at step 167

## Known good changes (updated)
- warmdown=0.4: big win at ~200 steps (1.124 vs 1.143 at 0.5, stable)
- warmdown=0.35: slightly better (1.121) but SPIKE at step 112 — unstable
- short_window//8: ~0.01 BPB improvement at ~200 steps
- MLP_ratio=3x: GLOBAL BEST 1.0799 (agent2) — smaller MLP → faster → more steps
