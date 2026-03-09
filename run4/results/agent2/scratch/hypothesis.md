# Current Hypothesis

## Experiment 3: Init scale 0.68x on current best (2**18 + RoPE200K)

### Theory
Karpathy found 0.68x init scale was optimal in his sweep. The current init uses
s = 3**0.5 * n_embd**-0.5 for uniform init. Multiplying by 0.68 could improve
training dynamics by starting from a slightly smaller initialization, which can
help with gradient flow in early training.

### Prediction
val_bpb: ~1.094-1.098. Small improvement or neutral. Init scale is one of those
things that either helps modestly or doesn't matter much.

### Risk
If 0.68 is too aggressive, could hurt convergence. But 0.68x is close to 1x.
