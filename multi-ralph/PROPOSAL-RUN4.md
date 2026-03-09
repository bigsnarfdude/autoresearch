# Run 4 Proposal: Multi-GPU Swarm with Cognitive Architecture

## Context

ICML 2026 is now — multi-GPU boxes are scarce. This proposal is designed to be ready when a box opens up, run fast (1-2 hours), and produce publishable results comparing 4 agent designs on the same hardware.

**Target hardware:** 4×A100 40GB PCIe (or 4×A100 80GB SXM4, or 4×H100)
**Budget:** 1-2 hours ($3-7 GPU + ~$5-10 Claude API)
**Goal:** Prove or disprove that agent cognitive architecture affects research quality

## What we already know (runs 1-3)

| Finding | Confidence | Source |
|---|---|---|
| Claude's gradient is consistent (same interventions found across runs) | HIGH | 3 runs |
| Single-ralph finds structural insights (depth reduction) | HIGH | Run 1 |
| Multi-ralph finds combinations faster | HIGH | Run 2 |
| Shared GPU serializes to expensive single-ralph | HIGH | Run 2 |
| Experiment budget is the outer loop's learning rate | THEORY | Cross-run analysis |
| Bigger model fails at 5-min budget (throughput > capacity) | HIGH | All 3 runs |

## The experiment: 4 agents, 4 GPUs, 4 cognitive architectures

**One agent per GPU. Same training code. Same 5-minute budget. Different "brains."**

This isolates the variable we actually care about: does the agent's cognitive architecture affect what it discovers?

### Agent 0: Vanilla (control)

```
agent0/
├── program.md          ← minimal: "edit train.py, run, check val_bpb"
└── results.tsv         ← append-only log
```

Baseline. No memory, no strategy, no structured thinking. Just the raw Claude loop from upstream autoresearch. Each iteration starts nearly from scratch (only sees results.tsv).

**Prediction:** Finds LR and warmdown wins (Claude's prior). Misses structural insights. Equivalent to run 1 experiments 1-10.

### Agent 1: Single-ralph (memory)

```
agent1/
├── program.md          ← full ralph-loop protocol
├── progress.md         ← cumulative history + strategic insights
└── next_ideas.md       ← ranked experiment queue
```

Proven design from run 1. Persistent memory, strategic reasoning, ranked idea queue. The agent that found depth reduction.

**Prediction:** Reproduces run 1 trajectory. Finds depth reduction around experiment 15-20. Best absolute BPB.

### Agent 2: Blackboard (shared reasoning)

```
agent2/
├── program.md          ← reads shared blackboard before each experiment
├── memory/
│   ├── facts.md        ← confirmed findings
│   ├── failures.md     ← dead ends (don't retry)
│   └── hunches.md      ← unconfirmed suspicions
├── scratch/
│   ├── hypothesis.md   ← current theory
│   └── predictions.md  ← expected outcome before each run
└── shared/
    └── blackboard.md   ← reads/writes claims visible to agent 3
```

New design. Structured memory (facts vs failures vs hunches). Scratchpad with predictions (makes reasoning inspectable). Shares a blackboard with agent 3.

**Prediction:** Fewer wasted experiments (failures.md prevents retries). Prediction tracking reveals Claude's calibration. Blackboard enables cross-agent building.

### Agent 3: Blackboard + Judge

```
agent3/
├── program.md          ← reads blackboard + judge reviews before each experiment
├── memory/             ← same as agent 2
├── scratch/            ← same as agent 2
├── shared/
│   └── blackboard.md   ← shared with agent 2
└── judge/
    └── reviews/
        └── exp_NNN.md  ← reviews OWN experiments for confounds
```

Same as agent 2, but after each experiment, the agent reviews its own result for confounds before marking keep/discard. "Is this improvement real or noise? Did I change two things at once? Is the step count comparable?"

**Prediction:** Fewer false positives. Slower (judge step costs ~30 seconds per experiment). But final config is more trustworthy.

## Protocol

### Setup (15 minutes)

```bash
# On the multi-GPU box
git clone https://github.com/bigsnarfdude/autoresearch.git
cd autoresearch
uv sync && uv run prepare.py

# Verify all 4 GPUs
nvidia-smi
uv run train.py  # solo baseline on GPU 0

# Create 4 worktrees
for i in 0 1 2 3; do
  git worktree add worktrees/agent$i -b agent$i
done

# Launch agents with staggered start (30 sec apart)
for i in 0 1 2 3; do
  screen -dmS ralph-agent$i bash -c "
    cd worktrees/agent$i
    export CUDA_VISIBLE_DEVICES=$i
    claude -p \"Read agent${i}_program.md. You are agent $i on GPU $i. Run experiments for 1 hour.\" \
      --dangerously-skip-permissions --max-turns 200
  "
  sleep 30
done
```

### Monitoring

```bash
# Watch all results
watch -n 10 'for i in 0 1 2 3; do echo "=== AGENT $i ===" && tail -3 worktrees/agent$i/results.tsv; done'

# GPU utilization (should show 4 independent processes)
watch -n 5 nvidia-smi

# Agent 2-3 blackboard activity
watch -n 10 cat shared/blackboard.md

# Agent 3 judge reviews
watch -n 10 'ls worktrees/agent3/judge/reviews/ | wc -l'
```

### Data collection (after 1 hour)

```bash
# Collect all results
for i in 0 1 2 3; do
  cp worktrees/agent$i/results.tsv results_agent$i.tsv
done

# Collect agent 1 memory
cp worktrees/agent1/progress.md agent1_progress.md

# Collect agent 2-3 structured memory
for i in 2 3; do
  cp -r worktrees/agent$i/memory/ agent${i}_memory/
  cp -r worktrees/agent$i/scratch/ agent${i}_scratch/
done

# Collect judge reviews
cp -r worktrees/agent3/judge/ agent3_judge/

# Collect shared blackboard
cp shared/blackboard.md blackboard_final.md
```

## What we measure

### Primary: BPB by agent design

| Metric | How | Answers |
|---|---|---|
| Best BPB per agent | results.tsv | Does cognitive architecture affect final quality? |
| BPB trajectory | BPB vs experiment number | Does memory accelerate convergence? |
| Time to first structural insight | Which experiment tries depth change | Does memory enable structural discovery? |

### Secondary: Research efficiency

| Metric | How | Answers |
|---|---|---|
| Experiments wasted | Results worse than baseline | Does failures.md reduce waste? |
| Prediction accuracy | scratch/predictions.md vs actual | Is Claude well-calibrated? |
| Confound detection | judge/reviews/ | Does self-review catch noise? |
| Cross-agent building | blackboard.md | Do agents build on each other's claims? |

### Meta: outer loop dynamics

| Metric | How | Answers |
|---|---|---|
| Improvement rate over time | BPB delta per experiment, rolling average | Does the outer optimizer converge? |
| Exploration dimension sequence | Which hyperparam changed per experiment | Does Claude follow a consistent gradient? |
| Discovery reproducibility | Compare agent 1 trajectory to runs 1 and 3 | Is the search path deterministic? |

## Hypotheses to test

**H1: Memory accelerates structural discovery.**
Agent 1 (single-ralph with progress.md) will discover depth reduction before agent 0 (vanilla). If agent 0 never finds it in 1 hour, memory is necessary for structural insights.

**H2: Structured memory reduces waste.**
Agents 2-3 (facts/failures/hunches) will have fewer experiments worse than baseline than agents 0-1. The failures.md file prevents retrying known dead ends.

**H3: Self-review catches noise.**
Agent 3 (with judge) will have fewer false-positive "keep" decisions than agent 2 (without judge). Testable by re-running agent 3's "keep" experiments and checking reproducibility.

**H4: Blackboard enables emergent collaboration.**
Agents 2 and 3, sharing a blackboard, will find a combination that neither would have found alone. The blackboard should show claim → response → experiment patterns.

**H5: Claude's gradient is consistent across architectures.**
All 4 agents will find matrix LR 0.08 and warmdown reduction in their first 5 experiments, regardless of cognitive architecture. The prior is in Claude, not in the harness.

**H6: Prediction tracking reveals calibration.**
Agent 2-3's prediction accuracy (predicted BPB vs actual BPB) will start poor (~0.01 error) and improve as experiments accumulate. If Claude is doing gradient descent, its landscape model should improve with more samples.

## Fallback: if only 2 GPUs available

Run agents 0+1 on GPU 0+1 (vanilla vs memory). This is the most important comparison — does persistent memory matter? The blackboard/judge experiments can wait for a 4-GPU box.

## Fallback: if only 1 GPU available (any size)

Run agents sequentially, 15 minutes each. Same first 3 experiments per agent. Less data but still tests H5 (consistency across architectures). Total: 1 hour, ~12 experiments per agent, ~$1-2 GPU.

## Estimated timeline

```
T+0:00   Box available. SSH in, clone, setup.
T+0:15   Solo baseline complete. Launch 4 agents.
T+0:20   All agents training (staggered start complete).
T+0:30   First results. Check GPU utilization = 4 independent processes.
T+0:45   ~10 experiments per agent. Check blackboard activity.
T+1:00   ~20 experiments per agent. Check for depth reduction (H1).
T+1:15   Collect data. Stop agents.
T+1:30   Analysis. Compare trajectories.
T+2:00   Done. Terminate box.
```

**Total cost:** ~$7-14 GPU + ~$5-10 Claude = $12-24 for a 4-way controlled experiment on agent cognitive architecture.

## Files to prepare before box is available

These can be written now and pushed to the repo:

1. `agent0_program.md` — vanilla (minimal instructions)
2. `agent1_program.md` — single-ralph (proven protocol from run 1)
3. `agent2_program.md` — blackboard + structured memory + predictions
4. `agent3_program.md` — blackboard + structured memory + predictions + judge
5. `shared/blackboard.md` — empty initial blackboard with format spec
6. `launch-run4.sh` — adapted launch script for 4 GPUs, staggered start
7. `collect-run4.sh` — data collection script

## What this proves for the paper

If the hypotheses hold:

> **LLMs as optimizers have tunable cognitive architecture.** Just as neural network training benefits from Adam over SGD (momentum, adaptive learning rates), LLM-driven hyperparameter search benefits from structured memory over flat logs, prediction tracking over blind exploration, and self-review over unchecked acceptance. The outer loop has its own hyperparameters — and they matter.

This is the missing piece from our current findings. We've shown Claude does gradient descent. Run 4 shows you can **improve the optimizer itself** by giving it better cognitive tools — the same way Adam improved on SGD.
