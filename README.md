# autoresearch (ralph fork, multi-agent ralph loop pattern)

> **TLDR:** 5 runs, 300+ experiments, 3 hardware configs. Claude agents autonomously optimize GPT-2 training — editing code, running experiments, keeping or discarding results. Best: **1.047 BPB** (8 agents on 8×A100, blackboard design wins). Key insight: Claude does gradient descent over hyperparameter space, and the gradient is consistent across independent runs. Extended to [AF elicitation](multi-ralph/domains/af-elicitation/) and [reactive agent dispatch](multi-ralph/conductor.sh) (Symphony-inspired).

Fork of [karpathy/autoresearch](https://github.com/karpathy/autoresearch) adding: **single-ralph** (persistent memory loop), **multi-ralph** (parallel agents with rotating coordinator), **cognitive architecture experiment** (8 agent designs), and **conductor** (reactive dispatch from shared blackboard).

## Results across 5 runs

| Run | Hardware | Agents | Design | Experiments | Best BPB | Key discovery |
|-----|----------|--------|--------|-------------|----------|---------------|
| 0 | RTX 4070 Ti 16GB (nigel) | 1 | human-in-loop | 46 | 1.150 | Depth reduction + LR scaling |
| 1 | RTX 4070 Ti 16GB | 1 | single-ralph | 42 | 1.150 | Reproduces Run 0 autonomously |
| 2 | 1×A100 40GB | 3 shared | multi-ralph | 20 | 1.180 | x0_lambda + combination search |
| 3 | RTX 4070 Ti 16GB | 1 | single-ralph | 5+ | 1.175 | Reproduces runs 0-2 findings |
| **4** | **8×A100 40GB** | **8 (1/GPU)** | **4 architectures** | **186** | **1.047** | **Blackboard wins; batch halving; all agents converge** |

### Run 4: 8 agents, 8×A100, 4 cognitive architectures — 186 experiments

8 agents with different "brains" on 8 dedicated GPUs. **Blackboard design wins.** Agents independently discovered batch halving (2\*\*19 → 2\*\*18 → 2\*\*17), matching [Karpathy's 125-experiment H100 run](https://github.com/karpathy/autoresearch/pull/2). Five agents converged to within 0.002 BPB.

| Rank | Agent | Design | Exps | Best | Key finding |
|------|-------|--------|------|------|-------------|
| 1 | **agent2** | **Blackboard** | 28 | **1.047** | Led discoveries: batch halving, MLP 3x, AR=96 |
| 2 | agent5 | Debate-A | 26 | 1.048 | Found mlr=0.03 + wd=0.1 |
| 3 | agent3 | Judge | 16 | 1.048 | Slowest throughput but converged |
| 4 | agent4 | Supervisor | 26 | 1.048 | Good strategic directives |
| 5 | agent6 | Debate-B | 27 | 1.048 | Consistent challenger |
| 6 | agent7 | BigBatch | 28 | 1.075 | batch=64 path; mlr=0.12 for large batch |
| 7 | agent1 | Memory | 17 | 1.082 | Found RoPE 200K (early #1 win) |
| 8 | agent0 | Vanilla | 18 | 1.123 | **No memory = repeated failures; proves architecture matters** |

**Winning config:** depth=8, AR=96, MLP 3x, TOTAL\_BATCH\_SIZE=2\*\*17, matrix\_lr=0.03-0.04, wd=0.1-0.2, ~930 steps.

### Run 0: Human-in-loop on nigel (RTX 4070 Ti) — 46 experiments

Best: **1.150 BPB** (from 1.193 baseline, -3.5%). The original manual exploration that established the search pattern.

| # | Experiment | val_bpb | Insight |
|---|-----------|---------|---------|
| 0 | Baseline (batch=32) | 1.193 | Initial |
| 4 | Matrix LR 0.08 + Embed LR 1.2 | 1.179 | Higher LR helps |
| 6 | Warmdown 0.5→0.3 | 1.177 | Less cooldown |
| 17 | **Depth 8→6** | **1.158** | **Biggest single win** |
| 25 | Depth 6→5 | 1.157 | Even smaller better |
| 32 | Window all-short | 1.155 | Faster + better quality |
| 42 | Cosine warmdown + softcap 8 | 1.150 | Final tuning |

### Run 1: Single-Ralph autonomous — 42 experiments

Best: **1.150 BPB** — independently reproduced Run 0's result with zero human input. Same depth reduction discovery, same LR scaling wins, same order of findings.

### Run 2: Multi-Ralph on 1×A100 (3 agents shared) — 20 experiments

Best: **1.180 BPB** (from 1.258 concurrent baseline, -6.2%). **Critical finding:** 3 agents sharing 1 GPU degraded to near-serial execution. Only 1.2× throughput, not 3×. Need 1 agent per GPU.

## What's consistent across all runs

| Intervention | Run 0 | Run 1 | Run 2 | Run 4 |
|---|---|---|---|---|
| Matrix LR 0.04→0.08 | -0.014 | -0.014 | -0.051 vs conc | - |
| Warmdown reduction | -0.016 | -0.016 | -0.050 vs conc | - |
| Increase model depth | worse | worse | worse | - |
| TOTAL_BATCH_SIZE halving | not tested | not tested | not tested | **-0.071** |

**Claude's ML intuitions are deterministic.** Five independent Claude instances, days apart, different hardware, different prompts — all converge on the same first wins. The gradient is learned from training data, not computed.

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

## Architecture

### Single-Ralph (1 agent, 1 GPU)

```
ralph-loop/
├── program.md        ← agent reads this every iteration
├── progress.md       ← best result, experiment history, strategic insights
└── next_ideas.md     ← ranked queue of experiments to try
```

### Multi-Ralph (N agents, N GPUs)

```
multi-ralph/
├── program-multi.md  ← rotating coordinator protocol
├── launch.sh         ← single GPU, N agents sharing
├── launch-8gpu.sh    ← multi GPU, 1 agent per GPU, cognitive architecture experiment
├── conductor.sh      ← reactive dispatch: watches blackboard, spawns agents on demand
├── WORKFLOW.md       ← agent lifecycle policy (stopping rules, escalation, protocol)
├── strategy.md       ← living search strategy
├── results.tsv       ← append-only experiment log from all agents
├── best/train.py     ← current global best
├── domains/          ← domain-specific workflows (af-elicitation, etc.)
├── queue/            ← pending experiment specs
├── active/           ← currently running
└── done/             ← completed experiment reports
```

### Conductor (Symphony-inspired reactive dispatch)

Instead of pre-assigning all experiments at launch, the conductor watches the blackboard for `REQUEST` lines and spawns ephemeral agents on demand. Agents generate work → conductor dispatches it → results flow back.

```bash
./multi-ralph/conductor.sh                          # default
./multi-ralph/conductor.sh --domain af-elicitation  # domain-specific workflow
./multi-ralph/conductor.sh --dry-run                # preview what would dispatch
```

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
| RTX 4070 Ti SUPER | 16GB | 1 | 32 | ~170-358 | Runs 0, 1, 3 |
| H100 80GB | 80GB | 1 | 128 | ~950 | Karpathy's setup |

## Smaller compute tips

From upstream: use [TinyStories](https://huggingface.co/datasets/karpathy/tinystories-gpt4-clean), lower `vocab_size` (4096/2048/1024/256), lower `MAX_SEQ_LEN` (down to 256), lower `DEPTH` (4), `WINDOW_PATTERN = "L"`, `TOTAL_BATCH_SIZE` down to `2**14`. See notable forks below.

## Key lessons

1. **TOTAL_BATCH_SIZE is the #1 lever.** Halving from 2\*\*19 to 2\*\*18 doubles steps and was the biggest single win. Found by Karpathy (125 exp) and independently by our agent 2 (run 4).
2. **Shared GPU serializes agents.** Multi-ralph on 1 GPU gave 1.2× throughput, not 3×. Need 1 agent per GPU.
3. **Symlinks must replace, not nest.** Git worktrees create real directories. `ln -sfn` into existing dir creates nested symlink. Must `rm -rf` first.
4. **Hyperparameters tuned at N steps don't transfer to 2N steps.** Old "best" config from run 2 (150 steps) was worse than baseline at run 4 (240 steps).
5. **Claude's gradient is consistent.** Same interventions found across all runs, regardless of hardware or agent design.
6. **Throughput > capacity at short budgets.** Smaller model + more steps beats bigger model + fewer steps at 5-minute wall clock. Flips at longer budgets.
7. **Architecture matters.** Vanilla agent (no memory) repeated the same failed experiments. Blackboard agent shared findings across the group. Memory is the difference between random search and gradient descent.

## Notable forks

- [miolini/autoresearch-macos](https://github.com/miolini/autoresearch-macos) (MacOS)
- [trevin-creator/autoresearch-mlx](https://github.com/trevin-creator/autoresearch-mlx) (MacOS)
- [jsegov/autoresearch-win-rtx](https://github.com/jsegov/autoresearch-win-rtx) (Windows)

## Documents

- **[multi-ralph/README.md](multi-ralph/README.md)** — Multi-agent details, conductor, domain extension
- **[multi-ralph/RESEARCHRALPH-V2.md](multi-ralph/RESEARCHRALPH-V2.md)** — v2 architecture: winning design, getting started
- [multi-ralph/EXTENDING.md](multi-ralph/EXTENDING.md) — Porting to other domains (compiler flags, SQL, trading, etc.)
- [multi-ralph/WORKFLOW.md](multi-ralph/WORKFLOW.md) — Agent lifecycle policy, blackboard protocol
- [FINDINGS.md](FINDINGS.md) — LLM as Optimizer thesis, cross-run analysis
- [EXPERIMENT-PROTOCOL.md](EXPERIMENT-PROTOCOL.md) — Full protocol, variables, metrics, reproducibility
- [multi-ralph/PROPOSAL-RUN4.md](multi-ralph/PROPOSAL-RUN4.md) — Run 4 design, hypotheses, predictions

## Origin

Built on [autoresearch](https://github.com/karpathy/autoresearch) by @karpathy. The ralph loop adds persistent memory. Multi-ralph extends to parallel agents. Run 4 tests cognitive architecture. The [conductor](multi-ralph/conductor.sh) adds [Symphony](https://github.com/openai/symphony)-inspired reactive dispatch — agents generate work items that spawn new agents.

## License

MIT
