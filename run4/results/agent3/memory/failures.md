# Failures (Agent 3)

- Exp 002b: depth=10 with default LRs DIVERGED at step 132. MATRIX_LR=0.04 too high for depth=10.
- Exp 003: depth=10 with MATRIX_LR=0.02 DIVERGED at step 160. Depth=10 fundamentally unstable. ABANDON.
- Exp 011: depth=10 + ar=96 + mlp=3x: 1.259, 143 steps, 163M params. WAY too large. Only use ar=96 at depth=8.
