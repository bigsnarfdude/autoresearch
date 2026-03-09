# Facts (confirmed findings)

## Hardware
- A100-SXM4-40GB, CUDA_VISIBLE_DEVICES=4
- 8 agents running concurrently
- DEVICE_BATCH_SIZE=32, TOTAL_BATCH_SIZE=2**17 (optimal)
- Run command: `.venv/bin/python train.py`

## My best config (GLOBAL BEST)
- exp19: 1.055344 — depth=8 AR=96 MLP3x 2**17 mlr=0.08 wd=0.2 RoPE200K init0.68, 933 steps, STABLE

## The winning recipe (Round 8)
- depth=8, AR=96 (768-dim, 6 heads), MLP 3x, 2**17 batch, mlr=0.08, wd=0.2
- RoPE200K, init0.68x, warmdown=0.5, warmup=0.0
- ~84.9M params, 15.6GB VRAM, ~900+ steps

## Batch size scaling
- 2**19: 1.133 (213 steps), 2**18: 1.075 (418 steps), 2**17: 1.055 (933 steps)
- 2**16: 1.068 (1735 steps) — TOO NOISY, regression
- 2**17 is optimal (grad_accum=2)

## Known bad
- 2**16 batch: too noisy
- emb_lr=0.9: hurts or neutral
- SwiGLU: hurts at depth=8
- AR>96: too wide
- depth=6: too shallow (1.079 at 456 steps)
- wd=0.15: worse than 0.2 (1.081 vs 1.076)
- softcap=30, warmdown!=0.5, adam_betas changes

## Unexplored at 2**17
- warmdown tuning (~900 steps regime)
- mlr tuning (0.06? 0.10?)
- MLP ratio (2.5x? 3.5x?)
- wd tuning (0.15? 0.25?)
- depth=10 at 2**17
