# Next Experiment Ideas

You are starting fresh. Build your own strategy.

## First Steps

1. **Establish baseline** — Run train.py as-is (after fixing DEVICE_BATCH_SIZE for this GPU). Record val_bpb, VRAM, steps, params.

2. **Explore the search space** — Based on the baseline, form hypotheses about what to improve. Consider:
   - Learning rate scaling (defaults may be tuned for more steps than this GPU can do)
   - Model size vs throughput tradeoff (smaller model = more steps in 5 min)
   - Schedule tuning (warmup, warmdown, final LR)
   - Optimizer parameters (weight decay, momentum, betas)
   - Architecture (window patterns, activation functions, softcap, embeddings)

Think carefully about what matters most given your specific GPU constraints, then prioritize.
