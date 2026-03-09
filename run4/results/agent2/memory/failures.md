# Dead Ends — NEVER retry

- matrix_lr=0.08 may be too aggressive for >200 steps
- warmup_ratio=0.05 hurts (agent4)
- warmdown > 0.5 catastrophic
- WARMUP_RATIO=0.1 on best config: 1.157 (agent5) — much worse
