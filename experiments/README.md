# Autoresearch Experiments

Systematic comparison of AI-driven research strategies on the same LLM training task.

## Experiment Design

All runs start from the **same baseline** (original train.py defaults) on the **same GPU** (RTX 4070 Ti SUPER, 16GB). Each run gets 50 iterations to optimize val_bpb.

### Runs

| Run | Strategy | Description |
|-----|----------|-------------|
| `0-manual` | Human-in-the-loop | Claude in conversation, human approving each step. (Already completed: 36 exps, 1.192→1.150) |
| `1-solo` | Single Ralph Loop | One `claude -p` in a bash loop, fully autonomous. Fresh context per iteration. |
| `2-solo` | Single Ralph Loop (repeat) | Same as 1-solo. Tests reproducibility — does it find the same insights? |
| `3-solo` | Single Ralph Loop (repeat) | Third run for statistical significance. |
| `4-wide` | Multi-Ralph (parallel) | Multiple Claude instances exploring different directions simultaneously, sharing results. |

### What we're measuring

- **Convergence**: Do independent runs reach similar val_bpb?
- **Path diversity**: Do they find the same winning changes or different ones?
- **Efficiency**: How many experiments to reach X% improvement?
- **Emergent strategies**: Does any run discover something the others missed?

## Folder Structure

```
experiments/
├── README.md           (this file)
├── baseline/
│   └── train.py        (frozen original — never modified)
├── 0-manual/
│   ├── results.tsv     (copied from our manual session)
│   └── progress.md     (final state from manual session)
├── 1-solo/
│   ├── ralph-loop/
│   │   ├── program.md
│   │   ├── progress.md
│   │   ├── next_ideas.md
│   │   └── run.sh
│   ├── results.tsv
│   └── train.py        (will diverge from baseline)
├── 2-solo/
│   └── (same structure)
├── 3-solo/
│   └── (same structure)
├── 4-wide/
│   ├── coordinator.sh   (launches multiple agents)
│   ├── shared-results.tsv (merged results from all agents)
│   ├── agent-0/
│   │   └── ralph-loop/
│   ├── agent-1/
│   │   └── ralph-loop/
│   └── agent-2/
│       └── ralph-loop/
└── analysis/
    └── compare.py      (cross-run analysis)
```

## GPU Time Budget

Each experiment = ~7 min (5 min training + 2 min overhead).
50 iterations = ~6 hours per solo run.
Can run solo runs sequentially overnight or parallel on different GPUs.
