# Current Hypothesis

## Experiment 002: Depth 10
- **Change**: DEPTH=8 → DEPTH=10 (single change)
- **Why**: Deeper models often learn better representations. With depth=10, model_dim=640, n_head=5, params ~78M. More params + more layers could offset slower step time.
- **Risk**: Slower per step → fewer total steps. If we get <150 steps, the comparison may not be fair.
- **Expected**: Improvement if enough steps complete. Predict ~1.16-1.18 BPB.
