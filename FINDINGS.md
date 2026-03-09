# LLM as Optimizer: Claude as Gradient Descent over Hyperparameter Space

## Thesis

Autoresearch is not just "an LLM running experiments." It's **gradient descent with Claude as the gradient estimator.** The LLM reads a loss value, reasons about the loss landscape, and proposes a weight update (code edit) — exactly what backpropagation does, but over hyperparameter and architecture space instead of parameter space.

This reframing explains every finding from our three independent runs.

| Gradient Descent | Claude Search | Evidence |
|---|---|---|
| Loss function | val_bpb | All decisions driven by single scalar |
| Gradient computation | Claude reads result + reasons about direction | "Matrix LR helped → try embedding LR next" |
| Weight update | `Edit train.py` | Each experiment modifies one or more hyperparameters |
| Learning rate | How bold the change is | 0.04→0.08 (conservative) vs 0.04→0.12 (aggressive, overshot) |
| Momentum | progress.md / strategy.md | Accumulated knowledge carries across experiments |
| Batch size | Experiments per decision | Single-ralph=1 (SGD), multi-ralph=N (mini-batch) |
| Gradient noise | Step count variance | 117-177 steps on shared GPU = noisy loss signal |
| Overshoot | Depth 12 on 16GB GPU | Too aggressive, catastrophic (1.542 vs 1.193 baseline) |
| Convergence | Diminishing returns after exp ~35 | Gains shrink from 0.014/exp to 0.001/exp |
| Learning rate schedule | 5-min budget = outer loop step size | Short budget = fast but noisy; long budget = slow but clean |

### Why this framing matters

**Claude's gradient is learned, not computed.** Backpropagation computes exact gradients. Claude *estimates* the gradient from its training data — millions of ML papers, experiment logs, and hyperparameter tuning guides. The 3-run reproducibility proves this estimate is consistent: three different Claude instances, days apart, all descend in the same direction (LR tuning → schedule → architecture).

**The outer loop has its own optimization dynamics.** The 5-minute training budget is the learning rate of the outer loop. Short budget = noisy gradient but fast iteration (12 experiments/hour). Long budget = clean gradient but slow iteration. This is why "bigger model always fails" at 5 minutes — it's not a statement about model scaling, it's a statement about the outer loop's step size being too small for the inner loop to converge.

**Single-ralph is SGD. Multi-ralph is mini-batch GD.** Single-ralph updates its "weights" (strategy, best config) after every single experiment — high variance, but each update uses the full sequential context. Multi-ralph accumulates N experiments before the coordinator updates strategy — lower variance per update, but each agent has less context. The explore/exploit tradeoff maps directly onto SGD vs mini-batch tradeoffs.

**The hybrid strategy is learning rate warmup.** Phase 1 (5 agents, short runs, wide sweep) = high learning rate with large batch. Phase 2 (2 agents, long runs, deep refinement) = low learning rate with small batch. This mirrors the warmup-then-decay schedule that works best in neural network training — and for the same reason: you want to explore broadly first, then converge precisely.

### Predictions from this framing

If Claude is doing gradient descent, then known optimization phenomena should appear:

1. **Loss plateaus followed by breakthroughs.** Run 1 showed this: experiments 4-15 were incremental LR tuning (plateau), then experiment 17 was depth reduction (breakthrough). This looks like escaping a local minimum — the LR subspace was exhausted, forcing exploration of a new dimension.

2. **Longer runs should flip the "bigger = worse" finding.** At 5 minutes, the outer loop's gradient says "smaller is better" because the inner loop (training) can't converge for big models. At 30+ minutes, the gradient should flip. This is testable.

3. **More agents should reduce variance but slow structural discovery.** Mini-batch GD converges more smoothly than SGD but can miss sharp minima. Multi-ralph found combinations faster but missed the depth reduction insight. Adding more agents should make this worse — you'd get reliable hyperparameter tuning but never the structural leaps.

4. **Claude's gradient should degrade on novel architectures.** Claude's loss landscape prior comes from training data (published ML results). On a truly novel architecture with no literature, the gradient estimate would be random — the LLM would be doing random search, not gradient descent. Testable by running autoresearch on a non-standard architecture.

## A vocabulary for the outer loop

There are two nested optimization loops in autoresearch. The inner loop (PyTorch training) has well-established vocabulary: learning rate, momentum, batch size, weight decay. The outer loop (Claude proposing experiments) has no standard terminology. We propose the following:

### Meta-parameters (outer loop)

These control Claude's search behavior. They are set by the human or the harness, not by Claude.

| Meta-parameter | What it controls | Analogous to | Our settings |
|---|---|---|---|
| `experiment_budget` | Wall-clock time per training run | Outer learning rate | 5 min |
| `memory_type` | Full history vs compressed summary | Adam (moments) vs SGD (stateless) | progress.md (full) / strategy.md (summary) |
| `memory_depth` | How many past experiments Claude sees | Optimizer context window | 42 (single) / ~20 lines (multi) |
| `agent_count` | Number of parallel agents | Outer batch size | 1 (single) / 3 (multi) |
| `boldness` | How far Claude jumps per experiment | Inner step size | Emergent (not explicitly set) |
| `exploration_dim` | Which subspace Claude searches | Search direction | Sequential (single) / all-at-once (multi) |
| `coordinator_freq` | How often strategy is re-evaluated | Gradient recomputation interval | Every experiment (single) / every round (multi) |
| `keep_threshold` | When to accept an experiment | Line search acceptance | Implicit (Claude decides) |

### Hyperparameters (inner loop)

Standard ML knobs that Claude edits in `train.py`: matrix_lr, embed_lr, unembed_lr, scalar_lr, warmdown_frac, FINAL_LR_FRAC, depth, model_dim, n_heads, weight_decay, softcap, x0_lambda, DEVICE_BATCH_SIZE, TOTAL_BATCH_SIZE.

### The coupling between loops

The outer loop's step size (`experiment_budget`) constrains which inner loop configurations are even evaluable:

```
5 min  + depth 5  = 358 steps → clean signal, small model
5 min  + depth 12 = 70 steps  → noisy signal, big model (unusable)
30 min + depth 12 = 420 steps → clean signal, big model (untested)
```

Claude cannot distinguish "depth 12 is bad" from "depth 12 needs more steps" without reasoning about this coupling. Run 1's agent did exactly this at experiment 17: "Speed > capacity on this GPU." The outer optimizer became aware of its own learning rate — meta-cognition as optimization.

This coupling means **you cannot tune the inner loop without understanding the outer loop's constraints.** A hyperparameter that's optimal at 358 steps may be suboptimal at 70 or 950 steps. The experiment budget is not just a resource constraint — it's a hyperparameter of the hyperparameter search.

### What makes this different from existing HPO

| Method | State | Prior | Reasons about coupling |
|---|---|---|---|
| Grid search | None | None | No |
| Random search | None | None | No |
| Bayesian optimization | Surrogate model | Kernel (GP, TPE) | No |
| Population-based training | Population fitness | Evolutionary | No |
| **Claude outer loop** | **progress.md (full history)** | **Learned from ML literature** | **Yes (experiment 17)** |

Traditional hyperparameter optimization is stateless or has a statistical surrogate. Claude has a *semantic* model of the loss landscape — it understands *why* a change helped ("higher LR helps because short schedules need faster convergence"), not just *that* it helped. This enables the structural leaps (depth reduction) that no surrogate-based method would propose, because they require reasoning about the interaction between model architecture and optimization dynamics.

The closest analogy in existing ML is **neural architecture search (NAS) with a learned controller** — but even NAS controllers operate over a fixed search space with fixed training budgets. Claude defines its own search space dynamically, adjusts its strategy based on accumulated results, and reasons about the budget constraint as part of the search.

## Summary

Three independent runs tested on the same codebase (autoresearch, TinyStories LLM training):

- **Run 1 — Single-ralph (deep):** 1 agent, 42 sequential experiments, ~3.5 hours on RTX 4070 Ti SUPER (16GB)
- **Run 2 — Multi-ralph (wide):** 3 concurrent agents, 20 experiments, ~1 hour on A100 SXM4 (40GB)
- **Run 3 — Single-ralph (replication):** 1 agent, in progress on RTX 4070 Ti SUPER (16GB)

All runs improved val_bpb (bits per byte, lower = better) from their respective baselines. The same interventions help across all runs, but the *types* of discoveries differed by agent design — confirming that the optimization dynamics of the outer loop (Claude) matter as much as the inner loop (training).

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

## The serialization problem: multi-ralph on shared GPU

The most important empirical finding: **3 agents sharing 1 GPU degraded into near-serial execution**, effectively becoming an expensive version of single-ralph.

### Evidence

1. **Step count variance reveals staggering, not parallelism.** Agents got 117-177 steps per run (30% variance). True concurrent execution would show similar step counts. Instead, agents naturally staggered — when one was training, others were compiling, waiting, or checking GPU state.

2. **Throughput math.** Solo baseline: 355 steps in 5 minutes. Three concurrent agents: ~140 steps each. Total steps: 3×140 = 420 vs 355 solo — only a **1.2× improvement**, not 3×. The GPU was time-slicing, not truly parallel.

3. **Agent self-throttling.** Agents learned to run `sleep 120 && nvidia-smi` before starting training, checking if the GPU had headroom. This turned concurrent agents into a polite queue. The coordinator protocol, designed for multi-GPU, became overhead on single-GPU.

4. **torch.compile stagger.** Compilation allocates ~17GB temporarily (vs ~12GB steady state). With 40GB total, only 2 processes can compile simultaneously. The third waits. This created accidental temporal staggering that *prevented OOM but also prevented true concurrency*.

### Why this matters

Multi-ralph's value proposition is **wide exploration** — testing many hypotheses simultaneously. On shared GPU, agents explore sequentially with coordination overhead. The 20 experiments in 1 hour could have been ~15 experiments with single-ralph on the same hardware (fewer steps per run due to no contention, but no coordinator overhead).

The protocol works — agents coordinate, share results, rotate coordinator roles, and avoid conflicts. But the underlying assumption (each agent has independent compute) was violated.

### Solutions

**1. Multi-GPU box (best solution)**
One agent per GPU. A 4×A100 box gives 4 truly independent training processes. Each gets full 355 steps. Total throughput: 4×355 = 1,420 steps per round vs 420 on shared GPU. The rotating coordinator protocol was designed for this — it would work as intended.

**2. Bigger single GPU (partial solution)**
A 96GB GPU (H100, A100 80GB) with batch=64 gives ~17GB per process. Three agents at 51GB leaves 45GB headroom — enough for torch.compile spikes. Agents would still contend for compute cores, but memory wouldn't be the bottleneck. Expected: ~250 steps each (vs 140 on 40GB), total 750.

**3. Constraining agents (risky but testable)**
- Remove `nvidia-smi` checks from agent prompts — force them to start training immediately instead of self-throttling
- Set `CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=33` — give each process exactly 1/3 of GPU compute via MPS (Multi-Process Service)
- Accept occasional OOM during torch.compile — add retry logic instead of avoidance
- Risk: more OOMs, but also more true concurrency. The agents' politeness was the problem.

**4. Staggered launch (simple mitigation)**
Launch agents 90 seconds apart instead of simultaneously. By the time agent 2 starts compiling, agent 0 has settled to steady-state VRAM. Reduces compile-time contention without constraining agents.

### Recommendation

For the planned 96GB hybrid run: use solution 2 (bigger GPU) + solution 4 (staggered launch). Phase 1 with 5 agents at batch=64 on 96GB gives each agent ~17GB with plenty of headroom. Staggered launch prevents compile-time OOM. For production multi-ralph: solution 1 (multi-GPU) is the only way to get true N× throughput.

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

## Cross-run reproducibility: 3 runs, same insights

Three independent runs on different hardware, agent configurations, and batch sizes converge on the same findings. This is the strongest evidence that the results are real, not artifacts of the harness.

### The three runs

| | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| **Mode** | Single-ralph | Multi-ralph (3 agents) | Single-ralph |
| **GPU** | RTX 4070 Ti SUPER 16GB | A100 SXM4 40GB | RTX 4070 Ti SUPER 16GB |
| **Batch size** | 32 | 32 (×3 concurrent) | 16 |
| **Steps/run** | 169-358 (depth dependent) | 117-177 (contention dependent) | 167 |
| **Total experiments** | 42 | 20 | 5+ (in progress) |
| **Baseline BPB** | 1.193 | 1.095 solo / 1.258 concurrent | 1.193 |
| **Claude model** | Sonnet | Sonnet | Sonnet |
| **Date** | Mar 7-8 | Mar 8 | Mar 9 |

### What's deterministic

**1. Same baseline on same GPU.** Runs 1 and 3 both produce 1.193 BPB baseline on the same RTX 4070 Ti despite different batch sizes (32 vs 16) and different dates. Step counts are nearly identical (169 vs 167 at depth 8). The training process is reproducible.

**2. Same winning interventions.** All 3 runs independently discover matrix LR 0.08 and warmdown reduction as improvements. No run found these to be harmful. Claude (the researcher agent) converges on the same hyperparameter insights regardless of agent design, hardware, or exploration order.

| Intervention | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Matrix LR 0.04→0.08 | -0.014 (exp 4) | -0.051 vs conc (exp 001) | -0.018 (exp 4) |
| Warmdown 0.5→0.3 | -0.016 (exp 6) | -0.050 vs conc (exp 008) | -0.008 (exp 2) |
| Increase depth | never tried up | +0.001 depth 9 (exp 003) | +0.349 depth 12 (exp 1) |

**3. Bigger model always fails under fixed time budget.** Every run that tried increasing model size got burned — not because bigger models are worse, but because the 5-minute training constraint means bigger models get fewer optimization steps. Run 2 tried depth 9 (117 steps, neutral-to-worse). Run 3 tried depth 12 (70 steps, catastrophic — 1.542). Run 1 went the other direction (depth 8→6→5, up to 358 steps) and found the biggest win. The insight is "throughput beats capacity at short schedules" — a smaller model trained for 358 steps learns more than a larger model trained for 70. This would flip on longer training budgets where bigger models eventually win, but within autoresearch's 5-minute constraint, it's a consistent finding across all hardware.

### What varies

**1. Discovery order.** Run 1: LR tuning → warmdown → architecture. Run 3: warmdown → LR tuning. Multi-ralph: all simultaneously. The harness (sequential vs parallel) affects the *path* through search space but not the *destination*. This suggests the loss landscape has clear gradients that any systematic search will follow.

**2. Improvement magnitude.** Matrix LR 0.08 gives -0.014 on run 1, -0.018 on run 3, and -0.051 (vs concurrent baseline) on run 2. The absolute numbers differ because baselines differ (more steps = lower baseline = harder to improve). The *direction* is always the same.

**3. Strategic depth.** Run 1 (42 experiments) discovered depth reduction at experiment 17 — a structural insight requiring accumulated context. Run 3 is too early to tell. Run 2 (multi-ralph) never tried depth reduction — the parallel agents stayed in hyperparameter space. The agent design *does* affect what gets discovered, even if the easy wins are the same.

### What this tells us

**The harness matters less than you'd think.** Single-ralph, multi-ralph, batch=16, batch=32 — the first 5 experiments always find the same things. The protocol (program.md, coordinator rotation) is scaffolding; the actual research signal comes from the training dynamics.

**The GPU matters for ceiling, not direction.** A100 with 355 steps reaches a lower baseline (1.095) than RTX 4070 Ti with 167 steps (1.193). But both benefit from the same interventions in the same direction. More compute raises the ceiling, it doesn't change which hyperparameters matter.

**The agent (Claude) is remarkably consistent.** Three different Claude instances, days apart, with different prompts and contexts, all converge on matrix LR and warmdown as the first wins. This suggests Claude's ML intuitions (from training data) are stable enough to be a reliable hyperparameter searcher — it's not randomly exploring, it's applying learned priors.

**The interesting question is structural discovery.** The easy hyperparameter wins (LR, warmdown) are deterministic. The hard insight (depth reduction, "speed > capacity") required 17 experiments of sequential context in run 1. Will run 3 find it? If yes, at roughly the same point, that's strong evidence that Claude's research reasoning is systematic, not lucky.

## Raw data

Full experiment logs:
- Single-ralph run 1: `ralph-loop/progress.md` (42 experiments, RTX 4070 Ti, batch=32)
- Multi-ralph run 2: `multi-ralph/results.tsv` (20 experiments, A100 40GB, 3 agents)
- Multi-ralph strategy: `multi-ralph/strategy.md`
- Single-ralph run 3: nigel:`~/autoresearch/experiments/1-solo/results.tsv` (in progress, RTX 4070 Ti, batch=16)
