# autoresearch (ralph fork)

Fork of [karpathy/autoresearch](https://github.com/karpathy/autoresearch) adding autonomous research agent modes: **single-ralph** (persistent memory loop), **multi-ralph** (parallel agents with rotating coordinator), and a **cognitive architecture experiment** comparing 4 agent designs on 8×A100.

## Results across 4 runs

### The punchline

4 independent runs, 3 hardware configs, 2 agent designs — same discoveries emerge every time. Claude does gradient descent over hyperparameter space, and the gradient is consistent.

| Run | Hardware | Agents | Design | Experiments | Best BPB | Key discovery |
|-----|----------|--------|--------|-------------|----------|---------------|
| 1 | RTX 4070 Ti 16GB | 1 | single-ralph | 42 | 1.150 | Depth reduction (speed > capacity) |
| 2 | 1×A100 40GB | 3 shared | multi-ralph | 20 | 1.180 | x0_lambda + combination search |
| 3 | RTX 4070 Ti 16GB | 1 | single-ralph | 5+ | 1.175 | Reproduces runs 1-2 findings |
| 4 | 8×A100 40GB | 8 (1/GPU) | 4 architectures | 91+ | **1.080** | Blackboard agent wins; matches Karpathy's #1 |

### Run 4: 8 agents, 8×A100, 4 cognitive architectures — 91 experiments

8 agents with different "brains" on 8 dedicated GPUs. **Blackboard design wins.** Agent 2 independently discovered halving TOTAL_BATCH_SIZE — the same #1 win from [Karpathy's 125-experiment H100 run](https://github.com/karpathy/autoresearch/pull/2) — then combined it with MLP 3x, depth=10, and wider AR=76 to reach 1.080.

| Rank | Agent | Design | Exps | Best | Hit rate | Key finding |
|------|-------|--------|------|------|----------|-------------|
| 1 | **agent2** | **Blackboard** | 11 | **1.080** | 64% | MLP 3x + depth10 + 2\*\*18 + AR=76 |
| 2 | agent1 | Memory | 12 | 1.082 | 33% | RoPE 200K + init 0.68 + shortwin |
| 3 | agent6 | Debate-B | 10 | 1.083 | ~40% | Combined others' wins (challenger role) |
| 4 | agent7 | BigBatch | 11 | 1.095 | 55% | batch=64 capacity test |
| 5 | agent5 | Debate-A | 10 | 1.097 | 20% | Width path: ar=96 mlp3x warmup=0 |
| 6 | agent3 | Judge | 8 | 1.104 | 50% | Confirmed ar=96 win, slowest throughput |
| 7 | agent4 | Supervisor | 11 | 1.121 | 73% | Good directives, own experiments unstable |
| 8 | agent0 | Vanilla | 12 | 1.152 | 17% | **9 reverts — proves memory matters** |

**Cross-pollination in action:** Agent 1 found RoPE 200K. Agent 2 found batch halving. Agent 6 combined both with init 0.68. No single agent found the full winning combination — the system did. Agent 0 (vanilla, no memory) tried the same failing experiment 9 times.

See [multi-ralph/RESEARCHRALPH-V2.md](multi-ralph/RESEARCHRALPH-V2.md) for the distilled v2 architecture.

### Run 1: Single-Ralph on RTX 4070 Ti SUPER (16GB) — 42 experiments

Best: **1.150 BPB** (from 1.193 baseline, -3.6%)

| # | Experiment | val_bpb | Insight |
|---|-----------|---------|---------|
| 0 | Baseline (batch=32) | 1.193 | Initial |
| 4 | Matrix LR 0.08 | 1.179 | Higher LR helps |
| 6 | Warmdown 0.5→0.3 | 1.177 | Less cooldown |
| 17 | **Depth 8→6** | **1.158** | **Biggest single win** |
| 25 | Depth 6→5 | 1.157 | Even smaller better |
| 32 | Window all-short | 1.155 | Faster + better quality |
| 42 | Cosine warmdown | 1.150 | Smooth LR decay |

### Run 2: Multi-Ralph on 1×A100 40GB (3 agents shared) — 20 experiments

Best: **1.180 BPB** (from 1.258 concurrent baseline, -6.2%)

| Agent | Experiment | val_bpb | vs concurrent |
|-------|-----------|---------|---------------|
| agent2 | x0_lambda + matrix_lr 0.08 + RoPE 50K | 1.180 | -0.078 |
| agent2 | x0_lambda init 0.05 | 1.181 | -0.077 |
| agent1 | Matrix LR 0.04→0.08 | 1.207 | -0.051 |
| agent2 | Warmdown 0.3 | 1.208 | -0.050 |

**Critical finding:** 3 agents sharing 1 GPU degraded to near-serial execution. Only 1.2× throughput, not 3×. Agents self-throttled via nvidia-smi checks. The rotating coordinator protocol needs dedicated GPUs (run 4 confirms this).

## What's consistent across all runs

Every run, regardless of hardware, agent count, or cognitive architecture, finds the same things first:

| Intervention | Run 1 | Run 2 | Run 3 | Run 4 |
|---|---|---|---|---|
| Matrix LR 0.04→0.08 | -0.014 | -0.051 vs conc | -0.018 | - |
| Warmdown reduction | -0.016 | -0.050 vs conc | -0.008 | - |
| Increase model depth | worse | worse | worse | - |
| TOTAL_BATCH_SIZE halving | not tested | not tested | not tested | **-0.071** |

**Claude's ML intuitions are deterministic.** Three different Claude instances, days apart, with different prompts, all converge on matrix LR and warmdown as the first wins. The gradient is learned from training data (ML papers), not computed.

**Bigger model always fails at 5-minute budget.** Not because bigger is worse — because fewer optimization steps at fixed wall clock. Depth 12 at 70 steps (1.542) vs depth 5 at 358 steps (1.157). This would flip on longer training budgets.

## LLM as Optimizer: the thesis

Autoresearch is **gradient descent with Claude as the gradient estimator.** See [FINDINGS.md](FINDINGS.md) for the full analysis.

| Gradient Descent | Claude Search |
|---|---|
| Loss function | val_bpb |
| Gradient | Claude reads result + reasons |
| Weight update | Edit train.py |
| Learning rate | Experiment budget (5 min) |
| Momentum | progress.md / strategy.md |
| Batch size | Agent count (1=SGD, 8=mini-batch) |

The experiment budget is the **outer loop's learning rate**. Short budget = noisy gradient, fast iteration. Long budget = clean gradient, slow iteration. Single-ralph is SGD. Multi-ralph is mini-batch GD. The hybrid strategy is learning rate warmup.

## Architecture

### Single-Ralph (1 agent, 1 GPU)

```
ralph-loop/
├── program.md        ← agent reads this every iteration
├── progress.md       ← best result, experiment history, strategic insights
└── next_ideas.md     ← ranked queue of experiments to try
```

Fresh context each iteration — all state lives in files. Runs indefinitely.

### Multi-Ralph (N agents, N GPUs)

```
multi-ralph/
├── program-multi.md  ← rotating coordinator protocol
├── launch.sh         ← single GPU, N agents sharing
├── launch-8gpu.sh    ← multi GPU, 1 agent per GPU, cognitive architecture experiment
├── strategy.md       ← living search strategy (updated by coordinator)
├── results.tsv       ← append-only experiment log from all agents
├── best/train.py     ← current global best
├── queue/            ← pending experiment specs
├── active/           ← currently running
└── done/             ← completed experiment reports
```

**Rotating coordinator:** No central supervisor. Whichever agent finishes first reads all results, generates next batch, picks one, trains. On 8 GPUs, steady state is ~87 experiments/hour.

### Run 4 additions (cognitive architecture)

```
run4/shared/
├── blackboard.md     ← agents post claims, responses, requests

Per-agent (worktrees/agent{N}/):
├── memory/           ← facts.md, failures.md, hunches.md
├── scratch/          ← hypothesis.md, predictions.md
├── judge/reviews/    ← self-review (agent 3)
├── supervisor/       ← oversight.md, trajectory.md (agent 4)
└── debate/           ← debate rounds (agents 5-6)
```

## Quick start

**Requirements:** NVIDIA GPU, Python 3.10+, [uv](https://docs.astral.sh/uv/), [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

```bash
git clone https://github.com/bigsnarfdude/autoresearch.git
cd autoresearch
uv sync
uv run prepare.py

# Set batch size for your GPU (32 for 16GB, 64 for 40GB solo, 128 for 80GB+)
sed -i 's/DEVICE_BATCH_SIZE = 128/DEVICE_BATCH_SIZE = 32/' train.py
uv run train.py   # verify baseline
```

### Single-Ralph

```bash
screen -dmS ralph claude -p "Read ralph-loop/program.md. Run on this machine. \
  CUDA_VISIBLE_DEVICES=0. Run experiments forever." \
  --dangerously-skip-permissions --max-turns 200
```

### Multi-Ralph (multi-GPU)

```bash
# 8 GPUs: cognitive architecture experiment
./multi-ralph/launch-8gpu.sh

# Or N agents on 1 GPU (shared)
./multi-ralph/launch.sh 3
```

### Monitor

```bash
screen -ls                             # list sessions
cat multi-ralph/results.tsv            # all results
cat multi-ralph/strategy.md            # search strategy
cat run4/shared/blackboard.md          # agent collaboration
watch -n 5 nvidia-smi                  # GPU usage
```

## Hardware adaptation

| GPU | VRAM | Agents | Batch | Steps/5min | Notes |
|-----|------|--------|-------|------------|-------|
| 8×A100 SXM4 40GB | 320GB | 8 (1/GPU) | 32 | ~240 each | Run 4, CPU contention |
| 1×A100 SXM4 40GB | 40GB | 3 (shared) | 32 | ~140 each | Run 2, GPU contention |
| 1×A100 SXM4 40GB | 40GB | 1 (solo) | 64 | ~355 | Run 2 baseline |
| RTX 4070 Ti SUPER | 16GB | 1 | 32 | ~170-358 | Runs 1, 3 |
| H100 80GB | 80GB | 1 | 128 | ~950 | Karpathy's setup |

## Key lessons

1. **TOTAL_BATCH_SIZE is the #1 lever.** Halving from 2\*\*19 to 2\*\*18 doubles steps and was the biggest single win. Found by Karpathy (125 exp) and independently by our agent 2 (run 4).
2. **Shared GPU serializes agents.** Multi-ralph on 1 GPU gave 1.2× throughput, not 3×. Need 1 agent per GPU.
3. **Symlinks must replace, not nest.** Git worktrees create real directories. `ln -sfn` into existing dir creates nested symlink. Must `rm -rf` first.
4. **Hyperparameters tuned at N steps don't transfer to 2N steps.** Old "best" config from run 2 (150 steps) was worse than baseline at run 4 (240 steps).
5. **Claude's gradient is consistent.** Same interventions found across all runs, regardless of hardware or agent design.
6. **Throughput > capacity at short budgets.** Smaller model + more steps beats bigger model + fewer steps at 5-minute wall clock. Flips at longer budgets.

## Documents

- **[multi-ralph/RESEARCHRALPH-V2.md](multi-ralph/RESEARCHRALPH-V2.md)** — v2 architecture: winning design, getting started, domain adaptation
- [multi-ralph/EXTENDING.md](multi-ralph/EXTENDING.md) — Porting to other domains (compiler flags, SQL, trading, etc.)
- [FINDINGS.md](FINDINGS.md) — LLM as Optimizer thesis, cross-run analysis, meta-parameters, serialization problem
- [EXPERIMENT-PROTOCOL.md](EXPERIMENT-PROTOCOL.md) — Full protocol, variables, metrics, reproducibility
- [multi-ralph/PROPOSAL-RUN4.md](multi-ralph/PROPOSAL-RUN4.md) — Run 4 design, hypotheses, predictions

## Origin

Built on [autoresearch](https://github.com/karpathy/autoresearch) by @karpathy. The ralph loop adds persistent memory. Multi-ralph extends to parallel agents. Run 4 tests cognitive architecture — whether memory, self-review, debate, and supervision make Claude a better optimizer.

## License

MIT
