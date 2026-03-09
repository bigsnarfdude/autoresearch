# Experiment Protocol: LLM as Optimizer

## What we're studying

Can an LLM (Claude) do gradient descent over hyperparameter space? And if so, can we improve the optimizer by giving it better cognitive tools?

## The two loops

```
OUTER LOOP                              INNER LOOP
(Claude decides what to try)            (PyTorch trains the model)

    ┌──────────────┐                    ┌──────────────┐
    │              │   edits train.py   │              │
    │   Claude     │ ──────────────►    │   PyTorch    │
    │              │                    │              │
    │  reads loss  │ ◄──────────────    │  trains LLM  │
    │  reasons     │     val_bpb        │  5 minutes   │
    │  proposes    │                    │  ~170 steps   │
    │              │                    │              │
    └──────────────┘                    └──────────────┘
         │                                    │
         │ state persists                     │ state resets
         │ in files                           │ each run
         ▼                                    ▼
    progress.md                          model weights
    strategy.md                          (discarded)
    results.tsv
```

The inner loop is standard ML training. The outer loop is the experiment — Claude as optimizer.

## Control variables

These stay constant across ALL runs to ensure fair comparison:

```
FIXED (never change)
━━━━━━━━━━━━━━━━━━━
Codebase:           karpathy/autoresearch (our fork)
Task:               TinyStories language modeling
Metric:             val_bpb (bits per byte, lower = better)
Training budget:    5 minutes wall clock per experiment
Model architecture: GPT variant (depth/width vary, structure doesn't)
Optimizer:          Muon + Adam (as shipped)
Data:               TinyStories (fixed split, prepared once)
Evaluation:         Same val set, same BPB computation
Claude model:       Sonnet (same version across runs)
Seed:               Not fixed (we measure variance instead)
```

```
WHY THESE CHOICES
━━━━━━━━━━━━━━━━━
5-minute budget:    Short enough for rapid iteration (~12 exp/hr)
                    Long enough for signal (~170 steps at batch 32)
                    Creates the "throughput vs capacity" tension
                    that forces structural reasoning

TinyStories:        Small enough to train on consumer GPU
                    Complex enough that hyperparameters matter
                    Well-studied (leaderboard exists for comparison)

val_bpb:            Single scalar = clean gradient signal
                    Comparable across model sizes
                    No ambiguity in "better" (lower = better)
```

## Independent variables

What we change between runs:

```
RUN-LEVEL VARIABLES (one setting per run)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Variable              Values tested        Why
─────────────────────────────────────────────────────
GPU hardware          RTX 4070 Ti (16GB)   Different step counts,
                      A100 40GB            different batch sizes,
                      4×A100 40GB          different baselines

Agent count           1, 3, 4             Serial vs parallel
                                           outer loop

Compute isolation     Shared GPU           Tests serialization
                      1 GPU per agent      Tests true parallelism

Batch size            16, 32, 64          Affects VRAM, steps,
                                           and baseline BPB

Cognitive architecture  See "Agent designs" below
```

```
AGENT-LEVEL VARIABLES (planned for run 4)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Variable              Values tested        Why
─────────────────────────────────────────────────────
Memory type           None (vanilla)       Does memory help?
                      Flat (progress.md)   Does structure help?
                      Structured (facts/   Does separation of
                        failures/hunches)    knowledge types help?

Scratchpad            None                 Does explicit reasoning
                      With predictions       improve search?

Shared reasoning      None                 Does collaboration
                      Blackboard             emerge from shared
                                             reasoning?

Self-review           None                 Does quality control
                      Judge protocol         reduce false positives?
```

## Dependent variables

What we measure:

```
PRIMARY METRICS
━━━━━━━━━━━━━━

best_bpb              Lowest val_bpb achieved
                      = how good is the final answer?

bpb_trajectory        val_bpb vs experiment number
                      = how fast does the optimizer converge?

total_experiments      Count of completed experiments
                      = throughput of the outer loop

kept_experiments      Count of improvements found
                      = hit rate of the optimizer


SECONDARY METRICS
━━━━━━━━━━━━━━━━━

wasted_experiments    Results worse than baseline
                      = how often does the optimizer overshoot?

time_to_structural    Which experiment first tries depth change
                      = does the optimizer escape hyperparameter
                        local minima?

discovery_order       Sequence of dimensions explored
                      = is the gradient path consistent?

prediction_accuracy   Predicted BPB vs actual (agents 2-3)
                      = is Claude well-calibrated?

confounds_caught      Judge flags per experiment (agent 3)
                      = does self-review add value?

blackboard_exchanges  Claim → response patterns (agents 2-3)
                      = does collaboration actually happen?


META METRICS
━━━━━━━━━━━━

improvement_rate      BPB delta per experiment, rolling window
                      = is the outer optimizer's gradient shrinking?
                        (convergence detection)

exploration_entropy   Diversity of hyperparameters changed
                      = is the optimizer exploring or exploiting?
                        (should shift over time)

cross_run_agreement   Same intervention, same direction across runs
                      = is Claude's gradient learned or random?
```

## Completed runs

```
RUN 1: Single-Ralph, RTX 4070 Ti SUPER (16GB)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Date:            Mar 7-8, 2026
Duration:        ~3.5 hours
Agent design:    Single-ralph (progress.md + next_ideas.md)
GPU:             RTX 4070 Ti SUPER 16GB
Batch size:      32
Experiments:     42
Baseline BPB:    1.193
Best BPB:        1.150 (-3.6%)
Steps/run:       169 (depth 8) → 358 (depth 5)

Key findings:
  - LR tuning: all defaults need ~2× (exp 3-15)
  - Depth reduction: biggest single win (exp 17, -0.012)
  - "Speed > capacity": structural insight from accumulated context
  - Diminishing returns after exp 35 (~0.001/exp)

Data:            ralph-loop/progress.md
                 ralph-loop/next_ideas.md
```

```
RUN 2: Multi-Ralph, A100 SXM4 40GB (3 agents, shared GPU)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Date:            Mar 8, 2026
Duration:        ~1 hour
Agent design:    Multi-ralph (rotating coordinator, queue-based)
GPU:             A100 SXM4 40GB (shared by 3 agents)
Batch size:      32
Experiments:     20
Solo baseline:   1.095 (355 steps, no contention)
Conc baseline:   1.258 (141 steps, 3 agents sharing)
Best BPB:        1.180 (-6.2% vs concurrent baseline)
Steps/run:       117-177 (contention dependent)

Key findings:
  - x0_lambda=0.05 strongest single change
  - Combination search faster than single-ralph
  - Agents self-organized concurrent baseline
  - SERIALIZATION: degraded to near-serial execution
  - torch.compile stagger prevented OOM but also prevented concurrency

Data:            multi-ralph/results.tsv
                 multi-ralph/strategy.md
```

```
RUN 3: Single-Ralph replication, RTX 4070 Ti SUPER (16GB)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Date:            Mar 9, 2026
Duration:        In progress
Agent design:    Single-ralph (same as run 1)
GPU:             RTX 4070 Ti SUPER 16GB (same machine as run 1)
Batch size:      16 (differs from run 1)
Experiments:     5+ (in progress)
Baseline BPB:    1.193 (same as run 1 despite different batch)
Best BPB:        1.175 (exp 4, matrix LR 0.08)
Steps/run:       167

Key findings so far:
  - Same baseline as run 1 (reproducible)
  - Same winning interventions (LR 0.08, warmdown)
  - Different discovery order (warmdown first, then LR)
  - Depth 12 catastrophic failure (1.542, 70 steps)

Data:            nigel:~/autoresearch/experiments/1-solo/results.tsv
```

```
RUN 4: Multi-GPU swarm (PLANNED)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Date:            When 4×A100 box available (ICML causing scarcity)
Duration:        1-2 hours
Agent designs:   4 different cognitive architectures (see PROPOSAL-RUN4.md)
GPU:             4×A100 40GB PCIe (1 per agent)
Batch size:      32
Expected:        ~80 experiments (20 per agent)

Purpose:         Isolate cognitive architecture as variable
                 Test memory, scratchpad, blackboard, judge
                 First true multi-GPU test of coordinator protocol

Hypotheses:      H1-H6 (see PROPOSAL-RUN4.md)
```

## Cross-run comparison framework

How we compare results across runs with different hardware and settings:

```
PROBLEM: Different GPUs → different step counts → different baselines

  RTX 4070 Ti batch=32:  169 steps, baseline 1.193
  RTX 4070 Ti batch=16:  167 steps, baseline 1.193
  A100 solo batch=32:    355 steps, baseline 1.095
  A100 concurrent:       141 steps, baseline 1.258

  Can't compare absolute BPB across hardware.


SOLUTION: Compare RELATIVE improvement and DISCOVERY PATTERNS

  1. Normalize to baseline:
     improvement = (baseline - result) / baseline × 100%
     Run 1 best: (1.193 - 1.150) / 1.193 = 3.6%
     Run 2 best: (1.258 - 1.180) / 1.258 = 6.2% (vs concurrent)

  2. Compare discovery order:
     Which interventions found first? Same across runs?

  3. Compare trajectory shape:
     Fast early gains → plateau → structural leap → diminishing?
     Same shape across runs = consistent gradient

  4. Compare structural discovery:
     Did the agent find depth reduction? At what experiment?
     This is the key differentiator between agent designs.
```

```
TRAJECTORY COMPARISON (runs 1-3, first 5 experiments)

Experiment #    Run 1 (batch=32)    Run 2 (concurrent)    Run 3 (batch=16)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
0 (baseline)    1.193               1.258                 1.193
1               1.194 (wider dim)   1.207 (matrix LR)     1.542 (depth 12)
2               1.188 (depth 7)     1.223 (RoPE 50K)      1.185 (warmdown)
3               1.193 (revert)      1.333 (warmdown 0.7)  1.184 (warmdown)
4               1.179 (matrix LR)   1.242 (embed LR)      1.175 (matrix LR)

Pattern: ALL runs find matrix LR 0.08 by experiment 4-5.
         Discovery order varies. Direction never does.
```

## Reproducing our results

### Prerequisites

```bash
# Hardware: any NVIDIA GPU with 16GB+ VRAM
# Software: Python 3.10+, uv, CUDA toolkit
# Optional: Claude Code CLI (for agent loop)

git clone https://github.com/bigsnarfdude/autoresearch.git
cd autoresearch
uv sync
uv run prepare.py        # downloads TinyStories
uv run train.py           # verify baseline (~5 min)
```

### Running a single-ralph experiment

```bash
# Option 1: Interactive
claude --dangerously-skip-permissions
# then: "Read ralph-loop/program.md and start the experiment loop"

# Option 2: Headless
screen -dmS ralph claude -p \
  "Read ralph-loop/program.md. Run on this machine. \
   CUDA_VISIBLE_DEVICES=0. Run experiments forever." \
  --dangerously-skip-permissions --max-turns 200

# Monitor
tail -f ralph-loop/progress.md
```

### Running a multi-ralph experiment

```bash
# Adjust DEVICE_BATCH_SIZE for your GPU
# Rule: batch_size_vram × num_agents < total_GPU_VRAM

./multi-ralph/launch.sh 3    # 3 agents on 1 GPU
# or
./multi-ralph/launch.sh 4    # 4 agents on 4 GPUs (edit launch.sh first)

# Monitor
watch -n 5 'cat multi-ralph/results.tsv'
watch -n 5 'cat multi-ralph/strategy.md'
```

### Verifying a specific finding

To confirm that an intervention helps (e.g., matrix LR 0.08):

```bash
# 1. Run baseline
uv run train.py
# note val_bpb

# 2. Edit the hyperparameter
# in train.py: change matrix_lr from 0.04 to 0.08

# 3. Run again
uv run train.py
# note val_bpb

# 4. Compare
# Expect: lower val_bpb with matrix_lr=0.08
# Our results: -0.014 to -0.018 on RTX 4070 Ti
```

## The meta-question

This experiment protocol is itself a hypothesis:

> **Can we study LLM optimization dynamics the same way we study neural network optimization dynamics?**

If yes, then concepts like learning rate, momentum, batch size, convergence, and loss landscapes have meaningful analogs in the outer loop. The vocabulary transfers. The intuitions transfer. And the improvements transfer — just as Adam improved on SGD by adding momentum and adaptive rates, structured memory and self-review may improve on vanilla LLM search.

Runs 1-3 suggest the answer is yes. Run 4 is designed to confirm it.
