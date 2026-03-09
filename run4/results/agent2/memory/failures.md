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
- ADAM_BETAS=(0.9, 0.95): 1.099 vs 1.079 — catastrophic. Keep beta1=0.8.
- mlr=0.08 at depth=10: 1.0793 vs 1.0787 at mlr=0.04 (fewer steps: 353 vs 380). Keep mlr=0.04 for depth=10.
- emb_lr=0.9 + unemb=0.006 on best d8 AR96: 1.0799 vs 1.075. No improvement, fewer steps (391 vs 418).
- TOTAL_BATCH_SIZE=2**16: 1.0684 vs 1.0617 at 2**17. Too noisy with grad_accum=1. 2**17 is the sweet spot.
- SwiGLU MLP 2x at 2**17: 1.0566 vs 1.0482 (ReLU^2 MLP3x). Doesn't transfer to 900+ steps.
- mlr=0.02 at 2**17: 1.0482 same as mlr=0.04. 0.04 is the sweet spot (more steps).
