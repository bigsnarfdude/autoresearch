# Confirmed Facts

- Default baseline: ~1.095 val_bpb at 355 steps (solo run)
- 8-agent concurrent baseline: ~1.133 at 213 steps (CPU/IO contention)
- Triple combo (x0+mlr0.08+rope50k): 1.118 at 240 steps — worse than solo default
- weight_decay=0.05 on best config: 1.126 (agent1)
- **TOTAL_BATCH_SIZE=2**18: 1.1087 at 395 steps — GLOBAL BEST** (agent2 exp1)
  - Nearly doubles steps (395 vs 213) under 8-agent contention
  - 11.7GB VRAM, well within budget
- weight_decay=0.05 on 2**18: 1.1074 at 434 steps — marginal improvement over wd=0.2
- RoPE base 200K on 2**18: 1.098 (agent1) — CURRENT GLOBAL BEST
- DEVICE_BATCH_SIZE=32 is fixed constraint
- With 2**18 batch, grad_accum_steps = 4; steps vary 395-463 by contention
