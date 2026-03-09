# Agent 5 Failures

- SwiGLU + MLP3x: 1.132 vs 1.075 baseline. Too many params (99M vs 85M). Don't add gate with MLP3x.
- AR=128: 1.098. Model too large, fewer steps. AR=96 is the sweet spot.
- softcap=30: Always worse than 15.
- warmup=0.05 + wd=0.2: Terrible combo (1.141 vs 1.097).
- warmdown=0.4 at depth=8: Worse than 0.5.
- beta1=0.9: Worse than 0.8 (1.112 vs 1.097).
- finalLR=0.05: Worse (1.109 vs 1.097).
- mlr=0.04 at 2**19: Too conservative for depth=8.
