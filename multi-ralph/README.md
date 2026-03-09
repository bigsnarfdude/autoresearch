# Multi-Ralph Loop

Parallel multi-agent extension of [Karpathy's autoresearch](https://github.com/karpathy/autoresearch). Runs N Claude agents simultaneously with a rotating coordinator protocol — no central supervisor needed.

## Runs

### Run 2: 3 agents, 1×A100 40GB (shared GPU)
- **Date:** Mar 8, 2026
- **Script:** `launch.sh 3`
- **Result:** 1.180 BPB best (-6.2% vs concurrent baseline)
- **Finding:** Shared GPU serialized agents — only 1.2× throughput, not 3×
- **Data:** `results.tsv`, `strategy.md`

### Run 4: 8 agents, 8×A100 40GB (1 GPU each) — ACTIVE
- **Date:** Mar 9, 2026
- **Script:** `launch-8gpu.sh`
- **Hardware:** Lambda gpu_8x_a100 (8×A100 SXM4 40GB)
- **Goal:** Compare 4 cognitive architectures on same hardware
- **Data:** `results.tsv`, `../run4/shared/blackboard.md`, agent worktrees

## Run 4: Cognitive Architecture Experiment

8 agents, 8 GPUs, 4 different "brain" designs — same training code.

| Agent | GPU | Design | What it tests |
|-------|-----|--------|---------------|
| 0 | 0 | **Vanilla** (control) | Raw Claude, no memory, just results.tsv |
| 1 | 1 | **Single-ralph** (memory) | progress.md + next_ideas.md, proven from run 1 |
| 2 | 2 | **Blackboard** | Structured memory (facts/failures/hunches) + shared blackboard + prediction tracking |
| 3 | 3 | **Blackboard + Judge** | Same as 2 + self-review for confounds after each experiment |
| 4 | 4 | **Supervisor** | Trains + writes strategic oversight for all agents |
| 5 | 5 | **Debate A** | Proposes experiments, debates with agent 6 before running |
| 6 | 6 | **Debate B** | Challenges agent 5's proposals, runs own experiments |
| 7 | 7 | **Big Batch** | batch=64 instead of 32, tests larger models + capacity |

### What we're measuring

Does cognitive architecture affect research quality? If agent 1 (memory) finds structural insights that agent 0 (vanilla) misses, memory matters. If agents 2-3 (blackboard) build on each other's findings, collaboration matters. If agent 3 (judge) has fewer false positives, self-review matters.

### Shared state

All agents read/write the same files via symlinks:

```
multi-ralph/              ← shared directory (symlinked into each worktree)
├── results.tsv           ← ALL agents append here
├── strategy.md           ← search strategy, updated by agents
├── best/train.py         ← current global best config
├── queue/                ← pending tasks
├── active/               ← running now
└── done/                 ← completed reports

run4/shared/              ← run 4 specific
├── blackboard.md         ← agents 2-5 post claims, responses, requests

Per-agent (in worktrees/agent{N}/):
├── memory/facts.md       ← confirmed findings (agents 2-7)
├── memory/failures.md    ← dead ends (agents 2-7)
├── memory/hunches.md     ← suspicions (agents 2-7)
├── scratch/hypothesis.md ← current theory (agents 2-7)
├── scratch/predictions.md ← predicted vs actual BPB (agents 2-7)
├── judge/reviews/        ← self-reviews (agent 3 only)
├── supervisor/           ← oversight + trajectory (agent 4 only)
└── debate/               ← debate rounds (agents 5-6 only)
```

## Design

The core idea: **whichever agent finishes first becomes the coordinator.** It reads all results, reasons about the search space, and generates the next batch of experiments for other agents to pick up.

```
                    ┌─────────────────────────────────────┐
                    │     multi-ralph/ (shared files)     │
                    │                                     │
                    │  best/train.py    ← global best     │
                    │  strategy.md      ← search plan     │
                    │  results.tsv      ← all results     │
                    │  queue/           ← pending tasks    │
                    │  active/          ← running now      │
                    │  done/            ← completed        │
                    └──────────┬──────────────────────────┘
                               │ symlinked into each
            ┌──────────────────┼──────────────────────┐
            ▼                  ▼                       ▼
    worktrees/agent0/   worktrees/agent1/  ...  worktrees/agent7/
    (independent repo)  (independent repo)      (independent repo)
```

**IMPORTANT:** The symlink must replace the git worktree's local `multi-ralph/` directory. The launch script does `rm -rf "$TREE/multi-ralph" && ln -sfn "$SHARED_DIR" "$TREE/multi-ralph"`. Without this, agents write to separate local copies and can't see each other's results.

### Agent lifecycle

```
Agent finishes experiment
    │
    ├── Report result to results.tsv and done/
    │
    ├── Beat global best? → Update best/train.py + strategy.md
    │
    ├── Queue empty?
    │   ├── YES → Become coordinator:
    │   │         Read ALL results → Reason about search space
    │   │         → Generate 2-4 new tasks → Write to queue/
    │   │         → Pick one yourself → Run it
    │   │
    │   └── NO → Pick next task from queue/ → Run it
    │
    └── Loop forever
```

## Quick start

### Multi-GPU (run 4 style, recommended)

```bash
# On a multi-GPU box (Lambda, RunPod, etc)
git clone https://github.com/bigsnarfdude/autoresearch.git
cd autoresearch
uv sync && uv run prepare.py

# Set batch size for your GPU
sed -i 's/DEVICE_BATCH_SIZE = 128/DEVICE_BATCH_SIZE = 32/' train.py

# Verify one GPU works
CUDA_VISIBLE_DEVICES=0 uv run train.py

# Auth Claude Code
claude

# Launch 8 agents on 8 GPUs (cognitive architecture experiment)
./multi-ralph/launch-8gpu.sh
```

### Single GPU (run 2 style, 3 agents sharing)

```bash
# Adjust batch size: per_process_VRAM × num_agents < total_VRAM
# A100 40GB: batch=32 (~12GB each), 3 agents = 36GB
./multi-ralph/launch.sh 3
```

## Monitoring

```bash
# Sessions
screen -ls                                    # list all
screen -r ralph-agent0                        # attach (Ctrl+A D detach)

# Results
cat multi-ralph/results.tsv                   # all experiment results
cat multi-ralph/strategy.md                   # current search strategy

# Run 4 specific
cat run4/shared/blackboard.md                 # agent collaboration
cat worktrees/agent4/supervisor/oversight.md  # strategic overview
cat worktrees/agent5/debate/current.md        # debate in progress
ls worktrees/agent3/judge/reviews/            # judge reviews

# GPU
watch -n 5 nvidia-smi

# Dashboard
watch -n 30 'echo "=== RESULTS ==="; tail -20 multi-ralph/results.tsv; echo; echo "=== BLACKBOARD ==="; tail -10 run4/shared/blackboard.md'
```

## Stopping and data collection

```bash
# Stop all agents
for i in $(seq 0 7); do screen -S ralph-agent$i -X quit; done

# Collect run 4 data
mkdir -p run4/results
cp multi-ralph/results.tsv run4/results/final.tsv
cp multi-ralph/strategy.md run4/results/strategy_final.md
cp run4/shared/blackboard.md run4/results/blackboard_final.md
for i in $(seq 0 7); do
  cp -r worktrees/agent$i/memory run4/results/agent${i}_memory 2>/dev/null
  cp -r worktrees/agent$i/scratch run4/results/agent${i}_scratch 2>/dev/null
done
cp -r worktrees/agent3/judge run4/results/agent3_judge
cp -r worktrees/agent4/supervisor run4/results/agent4_supervisor
cp -r worktrees/agent5/debate run4/results/debate_archive

# Clean up worktrees
for i in $(seq 0 7); do git worktree remove --force worktrees/agent$i; done
```

## Hardware adaptation

| Setup | GPUs | Agents | Batch | Script | Steps/run |
|-------|------|--------|-------|--------|-----------|
| 8×A100 40GB | 8 | 8 (1 per GPU) | 32 | `launch-8gpu.sh` | ~240 (CPU contention) |
| 4×A100 40GB | 4 | 4 (1 per GPU) | 32 | adapt launch-8gpu.sh | ~300+ |
| 1×A100 40GB | 1 | 3 (shared) | 32 | `launch.sh 3` | ~140 each |
| 1×H100 96GB | 1 | 5 (shared) | 64 | `launch.sh 5` | ~300 each |
| 1×RTX 4070 Ti | 1 | 1 (single-ralph) | 32 | use ralph-loop/ | ~170-358 |

## Key lessons

1. **Symlinks must replace, not nest.** Git worktrees create real directories. `ln -sfn` into an existing dir creates a nested symlink. Must `rm -rf` first.
2. **Shared GPU serializes agents.** 3 agents on 1 GPU gave 1.2× throughput, not 3×. Use 1 agent per GPU.
3. **CPU/IO contention exists even with separate GPUs.** 8 agents on 8 GPUs still got ~240 steps vs 355 solo due to shared CPU/memory bus.
4. **TOTAL_BATCH_SIZE is searchable.** Halving to 2**18 was the #1 win on the H100 leaderboard. Don't lock it.
5. **Old "best" configs may not transfer.** Hyperparameters tuned at 150 steps (contention) are suboptimal at 240 steps (dedicated GPU).

## Conductor (Symphony-inspired reactive dispatch)

Instead of pre-assigning all experiments at launch, the conductor watches the blackboard for `REQUEST` lines and spawns ephemeral agents on demand.

```bash
# Run alongside existing agents — picks up REQUESTs they post
./multi-ralph/conductor.sh

# Domain-specific (uses domains/af-elicitation/WORKFLOW.md)
./multi-ralph/conductor.sh --domain af-elicitation

# Dry run — show what would be dispatched
./multi-ralph/conductor.sh --dry-run

# Tune concurrency
MAX_CONCURRENT=8 POLL_INTERVAL=15 ./multi-ralph/conductor.sh
```

### How it works

1. Running agents post `REQUEST agent2 to any: test monitoring differential` to the blackboard
2. Conductor polls blackboard every 30s, finds unhandled REQUESTs
3. Spawns an ephemeral agent in a fresh worktree with the request as its prompt
4. Ephemeral agent runs the experiment, posts results back to blackboard, exits
5. Conductor cleans up the worktree

This is the difference between "8 agents run once" and "agents run until the question is answered." Agent 5's monitoring differential test (designed in Run 1 but never executed because the Lambda box was terminated) would have auto-launched.

### WORKFLOW.md (agent policy)

Each domain gets a `WORKFLOW.md` that defines:
- **Stopping rules**: when to declare convergence vs keep exploring
- **Escalation**: what constitutes a blocking finding
- **Recording protocol**: what goes in results.tsv vs blackboard vs memory
- **Domain constraints**: false-positive modes, forbidden actions, safety rules

See `WORKFLOW.md` (base) and `domains/af-elicitation/WORKFLOW.md` (AF-specific).

## Extending to new domains

The multi-agent pattern is domain-agnostic. Any task with **editable parameters** and a **scalar objective** slots in. See `EXTENDING.md` for the full analysis.

### Minimal template

```
domains/your-domain/
├── WORKFLOW.md          # domain-specific agent policy
├── config.yaml          # the thing agents edit
├── run.sh               # harness: apply config → run → output score
├── results.tsv          # append-only experiment log
├── blackboard.md        # shared collaboration space
└── best/config.yaml     # current best configuration
```

### Proven domains

| Domain | Harness | Objective | Status |
|--------|---------|-----------|--------|
| GPT-2 training | `train.py` | val_bpb (lower=better) | 186 experiments, 1.047 BPB |
| AF elicitation | `elicit_and_score.sh` | elicit_rate × diversity (higher=better) | 7 experiments, signal decomposition |

See `domains/af-elicitation/WORKFLOW.md` and `af-elicitation-sketch.md`.

## Origin

Built on [autoresearch](https://github.com/karpathy/autoresearch) by @karpathy. The "ralph loop" pattern adds persistent memory and intelligent search to the original experiment loop. Multi-ralph extends it to parallel agents with a rotating coordinator protocol. Run 4 adds cognitive architecture comparison. The conductor adds [Symphony](https://github.com/openai/symphony)-inspired reactive dispatch — agents generate work items that spawn new agents.
