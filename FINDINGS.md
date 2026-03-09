# Deep vs Wide: Single-Ralph and Multi-Ralph Findings

## Summary

Two autonomous research strategies tested on the same codebase (autoresearch, TinyStories LLM training):

- **Single-ralph (deep):** 1 agent, 42 sequential experiments, ~3.5 hours on RTX 4070 Ti SUPER (16GB)
- **Multi-ralph (wide):** 3 concurrent agents, 20 experiments, ~1 hour on A100 SXM4 (40GB)

Both improved val_bpb (bits per byte, lower = better) from their respective baselines. But the *types* of discoveries differed fundamentally.

## Results at a glance

| | Single-Ralph (Deep) | Multi-Ralph (Wide) |
|---|---|---|
| GPU | RTX 4070 Ti 16GB | A100 SXM4 40GB |
| Agents | 1 | 3 concurrent |
| Wall clock | ~3.5 hours | ~1 hour |
| Total experiments | 42 | 20 |
| Experiments/hour | ~12 | ~20 |
| Steps per run | ~358 (solo) | ~140-177 (shared GPU) |
| Baseline BPB | 1.193 | 1.095 (solo) / 1.258 (concurrent) |
| Best BPB | **1.150** | **1.180** (concurrent) |
| Improvement | -3.6% | -6.2% (vs concurrent baseline) |
| Winning changes | 10 kept | 5 kept |

## What deep search found (single-ralph, 42 experiments)

The single agent built cumulative knowledge over 42 experiments, recorded in `progress.md`. Each experiment informed the next. The key breakthroughs came in clusters:

### Cluster 1: LR scaling (experiments 3-15)
Systematically tuned every learning rate dimension. Found that all defaults need ~2x for the short (~358 step) training regime: Matrix LR 0.04→0.08, Embedding LR 0.6→1.2, Unembedding LR 0.004→0.008, Scalar LR 0.5→1.0. Each was a small win; stacked together they moved from 1.193 to 1.169 (-2.0%).

### Cluster 2: Architecture reduction (experiments 17-25)
The biggest single insight: **shrinking the model helps more than tuning the big model.** Depth 8→6 was -0.012 BPB (experiment 17, the largest single gain). Depth 6→5 gave another -0.001. The agent's own words: "Speed > capacity on this GPU. Throughput (steps) matters more than model size."

This is a *structural* insight that required accumulated understanding. The agent had already tuned LRs optimally for depth 8, so it knew the improvement from depth 6 wasn't about LR headroom — it was genuinely about getting more optimization steps.

### Cluster 3: Training dynamics (experiments 32-42)
Late-stage refinements that required the foundation from clusters 1-2: all-short window pattern, faster Muon momentum warmup (300→100 steps — most of training was wasted in warmup), tighter softcap (15→10→8), cosine warmdown shape. Each was 0.001-0.003 BPB, but they stacked.

### Trajectory of discovery

```
Exp 0:  1.193 ████████████████████████████████████████████ baseline
Exp 4:  1.179 ██████████████████████████████████████████   LR tuning
Exp 15: 1.169 ████████████████████████████████████████     all LRs optimized
Exp 17: 1.158 █████████████████████████████████████        DEPTH 6 (structural leap)
Exp 25: 1.157 █████████████████████████████████████        depth 5
Exp 32: 1.155 ████████████████████████████████████         all-short windows
Exp 35: 1.153 ████████████████████████████████████         faster muon warmup
Exp 38: 1.151 ████████████████████████████████████         softcap 8
Exp 42: 1.150 ███████████████████████████████████          cosine warmdown
```

Note the shape: rapid early gains from LR scaling, a structural leap at experiment 17, then diminishing returns from dynamics tuning. The agent recognized this pattern and shifted strategy accordingly.

## What wide search found (multi-ralph, 20 experiments)

Three agents explored in parallel with a rotating coordinator protocol. The coordinator read all results and generated the next batch of tasks.

### Round 1: Broad sweep (experiments 1-8)
All three agents tested different dimensions simultaneously. In the time single-ralph would have done 2-3 experiments, multi-ralph tested: higher matrix LR, depth 9, RoPE 50K, warmdown 0.7, embedding LR changes, x0_lambda 0.05, window patterns, warmdown 0.3. This identified **x0_lambda=0.05** as the standout winner (-0.077 vs concurrent baseline).

### Round 2: Combination search (experiments 9-20)
The coordinator reasoned about round 1 results and generated combination experiments. Found that **x0_lambda + matrix_lr 0.08 + RoPE 50K** together beat any single change (1.180 vs 1.181 for x0_lambda alone). Also discovered that several combinations *don't* help: x0_lambda + warmdown 0.3, x0_lambda + softcap 30, x0_lambda + lower LRs.

### What multi-ralph couldn't do

Multi-ralph never tried reducing model depth — its most architecturally adventurous experiment was depth 9 (which was worse due to fewer steps). The agents stayed in hyperparameter space because:
1. With only ~140 steps per concurrent run, signal is noisy. Agents were conservative.
2. The coordinator prioritized combining known winners over structural experiments.
3. No single agent accumulated enough experience to make the "speed > capacity" leap.

## The core insight: exploration vs exploitation at different scales

Single-ralph and multi-ralph implement the explore/exploit tradeoff at different granularities:

**Single-ralph exploits within each dimension, then explores new dimensions.** It exhaustively searched LR space (6 experiments), found the optimum, then moved to architecture. This sequential depth meant it had full context when making the depth reduction leap — it *knew* the LRs were already optimal, so the depth improvement was real.

**Multi-ralph explores across all dimensions simultaneously, then exploits combinations.** It tested LR, architecture, schedule, and init all in one round. This found x0_lambda=0.05 (which single-ralph only tried at experiment 40, much later). But it couldn't do the deep sequential reasoning needed for structural insights.

| Discovery type | Single-ralph | Multi-ralph |
|---------------|-------------|-------------|
| Hyperparameter optima | Slow (sequential search) | Fast (parallel sweep) |
| Combinations | Very slow (one at a time) | Fast (coordinator generates combos) |
| Structural insights | **Strong** (accumulated context) | Weak (shallow per-agent context) |
| Diminishing returns detection | **Strong** (sees the curve) | Weak (noisy concurrent signal) |

## Emergent behaviors

### Single-ralph
- **Strategy shifts:** Recognized when LR tuning hit diminishing returns and pivoted to architecture search
- **Retrying failed ideas:** Re-tested Matrix LR 0.12 at depth 5 (exp 33) after it failed at depth 8 (exp 5) — different model size, different dynamics
- **Principled stopping:** Identified "diminishing returns territory" and shifted to simplification experiments

### Multi-ralph
- **Self-organized baselines:** Agents independently established a "concurrent baseline" for fair comparison when they realized GPU contention reduced steps
- **Constraint discovery:** When batch=64 OOMed with 3 concurrent processes, agents corrected strategy within one round
- **Natural staggering:** torch.compile memory spikes varied per agent, creating accidental but essential temporal staggering that prevented simultaneous OOM
- **Coordinator quality:** Whichever agent finished first generated thoughtful experiment batches with rationales — the quality of coordination improved as more results accumulated

## Implications for the 96GB hybrid strategy

Based on these findings, the planned 2-phase approach on a 96GB GPU:

**Phase 1 (hour 1): 5 agents at batch=64 — multi-ralph style wide sweep**
- Purpose: rapidly identify which dimensions matter (LR? architecture? init? schedule?)
- Expected: ~50 experiments covering the full search space
- Key: let multi-ralph's combination search find x0_lambda-style wins early
- Risk: noisy signal at ~300 steps with 5 agents — mitigated by batch=64 (vs 32 on A100)

**Phase 2 (hours 2-4): 2 agents at batch=128 — single-ralph style deep exploitation**
- Purpose: structural search + stacking winners with clean signal
- Expected: ~70 experiments with ~500 steps each
- Key: one agent combines phase 1 winners, one agent does architecture search (depth, width, components)
- The depth reduction insight (single-ralph exp 17) is the kind of win that only comes from clean, sequential reasoning

**Phase transition:** The coordinator from phase 1 writes a final `strategy.md` summarizing all findings before the switch. Phase 2 agents read this — they get the breadth of phase 1 with the depth of phase 2.

**Target:** Beat the H100 leaderboard baseline (0.998 BPB → 0.977 BPB range). Our best comparable result is 1.150 on 16GB / 1.095 solo on A100. With 96GB, batch=128, ~500 steps, and accumulated knowledge from both phases, sub-1.0 should be achievable.

## Raw data

Full experiment logs:
- Single-ralph: `ralph-loop/progress.md` (42 experiments)
- Multi-ralph: `multi-ralph/results.tsv` (20 experiments)
- Multi-ralph strategy: `multi-ralph/strategy.md`
