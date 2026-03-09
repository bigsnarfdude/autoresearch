# Hypothesis

## H1: Depth scaling at large batch
Bigger batch gives more gradient signal per step. Deeper models (depth 10, 12) might benefit
more from this than shallow models. Test: depth 10 at batch=64, compare relative improvement
vs depth 8 baseline.

## H2: LR scaling with batch size
batch=64 is 2x batch=32. Linear scaling rule suggests trying 2x LR. But sqrt scaling (1.41x)
might be better for Adam-like optimizers.
