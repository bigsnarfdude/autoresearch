# Dead Ends — NEVER retry

- matrix_lr=0.08 may be too aggressive for >200 steps
- warmup_ratio=0.05 hurts (agent4)
- warmdown > 0.5 catastrophic
- WARMUP_RATIO=0.1 on best config: 1.157 (agent5) — much worse
- softcap=30 at depth=10: 1.155 vs 1.084 — catastrophic. Keep softcap=15.
- HEAD_DIM=64: 1.107 (agent1) — worse than HEAD_DIM=128 at depth=8
- MLP_ratio=2.5: 1.0833 at depth=10 — worse than 3x (1.0799). Too narrow.
- short_window=seq//8 at depth=10: hurts (agent6: 1.139, me: 1.147)
- WARMDOWN_RATIO=0.4 at depth=10 MLP3x (430 steps): 1.082 vs 1.080 at 0.5. Slightly worse.
- EMBEDDING_LR=1.0: neutral (tested at depth=10)
