# researchRalph v2: Multi-Agent Autonomous Research Architecture

**Status:** Proven on TinyStories LLM training (91+ experiments, 8×A100). Ready for domain adaptation.

## What this is

A pattern for running N autonomous Claude agents that collaborate to optimize any system with editable parameters and a scalar objective. Each agent runs experiments, records results, and builds on other agents' discoveries through shared memory.

Run 4 proved: 8 agents found 2.4× the improvement of 1 agent in half the wall-clock time. The #1 discovery (TOTAL_BATCH_SIZE halving) was found independently — matching Karpathy's 125-experiment H100 result.

## The winning architecture

Run 4 tested 4 cognitive designs. Results after 91 experiments:

```
DESIGN RANKINGS (by best result achieved)

1. Blackboard       1.080 BPB   64% hit rate   WINNER
   structured memory (facts/failures/hunches) + shared blackboard + predictions

2. Memory           1.082 BPB   33% hit rate   CLOSE SECOND
   progress.md + next_ideas.md (single-ralph pattern)

3. Debate-B         1.083 BPB   ~40% hit rate  GOOD (challenger role)
   reads proposals, picks best parts, runs own experiments

4. BigBatch         1.095 BPB   55% hit rate   SPECIAL PURPOSE
   different batch size, tests capacity vs throughput

5. Judge            1.112 BPB   50% hit rate   OVERHEAD > VALUE
   self-review slowed throughput, overcautious "keep-but-confounded"

6. Supervisor       1.121 BPB   73% hit rate   GOOD VISION, BAD EXECUTION
   correct strategic directives but own experiments had loss spikes

7. Debate-A         1.126 BPB   20% hit rate   WORST NON-VANILLA
   proposer role adds constraints without benefits

8. Vanilla          1.152 BPB   17% hit rate   CONTROL (proves memory matters)
   no memory = 9 reverts out of 12 experiments, repeats mistakes
```

## v2 default agent design: Blackboard

Every agent in v2 uses the blackboard pattern unless there's a reason not to.

```
Per agent:
  memory/
    facts.md       # confirmed findings (append-only truths)
    failures.md    # dead ends — NEVER retry these
    hunches.md     # suspicions worth testing
  scratch/
    hypothesis.md  # current theory about what to try
    predictions.md # predicted vs actual score (calibration)

Shared (all agents read/write):
  results.tsv      # append-only experiment log
  strategy.md      # living search strategy
  best/config      # current global best configuration
  blackboard.md    # claims, responses, requests between agents
  queue/           # pending experiment specs (.md files)
  active/          # currently running (one per agent)
  done/            # completed experiment reports
```

### Agent lifecycle (every round)

```
1. Read strategy.md + blackboard.md + own memory/
2. Check queue/ — pick lowest-numbered task, or become coordinator if empty
3. cp best/config → local config
4. Apply changes from task
5. Predict expected score → scratch/predictions.md
6. Run experiment → capture score
7. Record: results.tsv (append), done/ (report), predictions (actual vs predicted)
8. Update memory: facts.md if confirmed, failures.md if dead end, hunches.md if unclear
9. If new best → update best/config + strategy.md + blackboard.md
10. If queue empty → become coordinator:
    - Read ALL results + blackboard + memory
    - Reason about search space (what's explored, what's not, what combinations untried)
    - Generate 2-4 new experiment specs → queue/
    - Pick one yourself
11. Loop forever
```

### Coordinator protocol (rotating, no central authority)

```
Agent finishes experiment
    │
    ├── Report to results.tsv + done/
    │
    ├── Beat best? → Update best/ + strategy.md + CLAIM on blackboard
    │
    ├── Queue empty?
    │   ├── YES → Become coordinator:
    │   │         Read ALL results → Reason about search space
    │   │         → Generate 2-4 tasks → queue/
    │   │         → Pick one → Run it
    │   │
    │   └── NO → Pick next task → mv queue/NNN.md active/agentN.md → Run it
    │
    └── Loop forever
```

### Blackboard protocol

Agents post structured messages:

```
CLAIM agentN: [finding with numbers]. [implication for other agents].
RESPONSE agentN to agentM: [confirmation or refutation with evidence].
REFUTE agentN: [finding] does NOT hold because [evidence].
REQUEST agentN to agentM: test [specific thing] because [reasoning].
```

This is how discoveries propagate. Agent 2 posted "TOTAL_BATCH_SIZE=2**18 is a massive win. All agents should use 2**18 as new baseline." Other agents picked it up.

## Getting started (new domain)

### Prerequisites

- N compute nodes (1 per agent, or shared with reduced throughput)
- Claude Code CLI installed and authenticated
- `screen` for session management
- `git` for worktree isolation

### Step 1: Define your domain

Create a directory with:

```
my-domain/
├── config.yaml          # the thing agents edit
├── run.sh               # harness: apply config → run → output score
├── program.md           # agent instructions (see template below)
├── results.tsv          # header: commit<tab>score<tab>status<tab>description<tab>agent
├── strategy.md          # initial: "## Baseline: [score]. No experiments yet."
├── blackboard.md        # initial: "# Shared Blackboard\n## Claims\n## Responses\n## Requests"
├── best/
│   └── config.yaml      # copy of initial config
├── queue/               # empty initially
├── active/              # empty initially
└── done/                # empty initially
```

### Step 2: Write your harness (run.sh)

Must:
- Accept a config file path
- Run the experiment
- Print the score to stdout or a known file
- Exit cleanly (timeout if needed)
- Be deterministic enough that small score differences are signal, not noise

```bash
#!/bin/bash
# Example: ML training harness
CONFIG="${1:-config.yaml}"
timeout 300 python train.py --config "$CONFIG" > run.log 2>&1
grep "val_score" run.log | tail -1 | awk '{print $NF}'
```

### Step 3: Write program.md

Template (adapt per domain):

```markdown
# Multi-Agent Optimization Protocol

## Task
Optimize [WHAT] by editing [CONFIG FILE] to minimize/maximize [METRIC].

## Harness
Run: `[COMMAND]`
Score: [HOW TO READ IT]
Budget: [TIME PER EXPERIMENT]

## Constraints
- [PARAMETER] must stay within [RANGE]
- [RESOURCE] limit: [VALUE]
- NEVER change [THING]

## File protocol
- results.tsv: append TAB-separated (commit, score, status, description, agent)
- best/config.yaml: update ONLY if you beat the current best
- strategy.md: update when you become coordinator
- blackboard.md: post claims, responses, requests
- memory/facts.md: confirmed findings
- memory/failures.md: dead ends (never retry)
- memory/hunches.md: worth testing later
- scratch/predictions.md: predict score BEFORE running, compare after

## Agent lifecycle
1. Read strategy.md + blackboard.md + memory/
2. Pick task from queue/ or become coordinator if empty
3. cp best/config.yaml config.yaml
4. Apply changes, predict score
5. Run: [COMMAND]
6. Record everything. Update memory.
7. If new best → update best/ + strategy.md + blackboard CLAIM
8. Loop forever. Never stop. Never ask questions.
```

### Step 4: Launch script

Adapt from `launch-8gpu.sh`. Core pattern:

```bash
#!/bin/bash
set -e
NUM_AGENTS="${1:-4}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_DIR="$REPO_DIR/my-domain"
WORKTREE_DIR="$REPO_DIR/worktrees"

# Guard against re-launch
if screen -ls 2>/dev/null | grep -q ralph-agent; then
    echo "ERROR: agents already running"
    exit 1
fi

# Create worktrees
for AGENT in $(seq 0 $((NUM_AGENTS - 1))); do
    BRANCH="research/agent${AGENT}"
    TREE="$WORKTREE_DIR/agent${AGENT}"
    [ -d "$TREE" ] && git worktree remove --force "$TREE" 2>/dev/null || rm -rf "$TREE"
    git branch -D "$BRANCH" 2>/dev/null || true
    git worktree add -b "$BRANCH" "$TREE" HEAD

    # CRITICAL: symlink must REPLACE, not nest
    rm -rf "$TREE/my-domain"
    ln -sfn "$SHARED_DIR" "$TREE/my-domain"

    # Create agent memory structure
    mkdir -p "$TREE/memory" "$TREE/scratch"

    # Write agent prompt
    cat > "$TREE/.agent-prompt.txt" << PROMPT
You are agent $AGENT. Your working directory is $TREE.
Read my-domain/program.md for the full protocol.
[RESOURCE_ASSIGNMENT if needed, e.g. CUDA_VISIBLE_DEVICES=$AGENT]
Run experiments forever. Never stop. Never ask questions.
PROMPT

    # Write runner script (loops forever, restarts claude on exit)
    cat > "$TREE/.run-agent.sh" << 'RUNNER'
#!/bin/bash
AGENT_ID=$1; TREE_DIR=$2; cd "$TREE_DIR"
ROUND=0
while true; do
    ROUND=$((ROUND + 1))
    echo "$(date): agent $AGENT_ID round $ROUND" >> agent.log
    claude -p "$(cat .agent-prompt.txt)
This is round $ROUND. Check strategy.md and blackboard.md for latest." \
        --dangerously-skip-permissions --max-turns 200 \
        2>> agent.log || true
    sleep 5
done
RUNNER
    chmod +x "$TREE/.run-agent.sh"
done

# Launch with staggered start (30s apart to avoid resource spikes)
for AGENT in $(seq 0 $((NUM_AGENTS - 1))); do
    TREE="$WORKTREE_DIR/agent${AGENT}"
    screen -dmS "ralph-agent${AGENT}" "$TREE/.run-agent.sh" "$AGENT" "$TREE"
    echo "Launched agent $AGENT"
    [ "$AGENT" -lt $((NUM_AGENTS - 1)) ] && sleep 30
done

echo "=== $NUM_AGENTS agents launched ==="
echo "Monitor: screen -r ralph-agent0"
echo "Results: cat my-domain/results.tsv"
echo "Strategy: cat my-domain/strategy.md"
echo "Blackboard: cat my-domain/blackboard.md"
echo "Stop: for i in \$(seq 0 $((NUM_AGENTS-1))); do screen -S ralph-agent\$i -X quit; done"
```

### Step 5: Monitor and intervene

```bash
# Watch results accumulate
watch -n 30 'cat my-domain/results.tsv | tail -20'

# Check agent collaboration
cat my-domain/blackboard.md

# Check search strategy
cat my-domain/strategy.md

# Intervene (append to blackboard or strategy)
echo "CLAIM OPERATOR: [directive]" >> my-domain/blackboard.md

# Add queue tasks manually
cat > my-domain/queue/999.md << 'EOF'
# Experiment 999: [title]
## Changes: [what to change]
## Expected: [predicted score]
EOF
```

## Key lessons from run 4

### What matters

1. **Blackboard > memory > vanilla.** Structured memory with shared communication wins. The 64% hit rate vs 17% (vanilla) proves cognitive architecture matters.

2. **Rotating coordinator works.** No central authority needed. Whichever agent finishes first generates next tasks. Steady state is ~11 experiments/hour/agent.

3. **Cross-pollination is the real value.** Agent 1 found RoPE 200K. Agent 2 found batch halving. Agent 6 combined both. No single agent found the winning combination — the system did.

4. **Memory prevents waste.** Agent 0 (vanilla) tried the same failing experiment 9 times. Agent 2 (blackboard) never repeated a failure. `failures.md` is the single most valuable file.

5. **1 agent per compute node.** Shared resources serialize agents. Run 2: 3 agents on 1 GPU = 1.2× throughput, not 3×.

### What doesn't matter

1. **Judge/self-review.** Adds overhead, slows throughput, doesn't catch real problems. Agent 3 did 8 experiments while others did 10-12. Overcautious labeling ("keep-but-confounded") prevented building on results.

2. **Debate (proposer role).** The proposer (agent 5) was constrained by the debate protocol. The challenger (agent 6) ignored the protocol and ran experiments — and outperformed.

3. **Supervisor oversight.** Agent 4 wrote excellent strategic directives. Its own experiments had loss spikes. The supervisor role takes context away from doing the actual work.

### What to watch for

1. **Stale prompts.** Agents re-read their initial prompt every round. If you fix a constraint (like TOTAL_BATCH_SIZE), the fix propagates through blackboard/strategy but not through the prompt. Write operator messages to blackboard.

2. **Symlink bug.** Git worktrees create real directories. `ln -sfn shared/ tree/shared` creates `tree/shared/shared` (nested). Must `rm -rf tree/shared && ln -sfn /path/to/shared tree/shared`.

3. **Step-count noise.** With shared CPU/IO, step counts vary ±20%. Small BPB differences (<0.002) may be noise, not signal.

4. **Hyperparameter transfer.** Optimal values at N steps don't transfer to 2N steps. When you change something that affects step count (like batch size), re-evaluate all hyperparameters.

## Adapting to other domains

See [EXTENDING.md](EXTENDING.md) for domain-specific gotchas and a feasibility tier list.

**Tier 1 (drop-in):** Compiler flags, prompt engineering, infrastructure config
**Tier 2 (feasible):** SQL optimization, ML hyperparameters, trading strategies
**Tier 3 (hard):** Drug molecules, chip design

The core requirements:
1. Editable config file (the "genome")
2. Scriptable harness that outputs a scalar score
3. Experiment completes in <30 minutes
4. Score is deterministic enough that 0.5% differences are signal
5. N compute nodes for N agents (or accept serialization penalty)

## Quick reference

```
Start:     ./launch.sh 4                          # 4 agents
Monitor:   watch -n 30 'cat results.tsv | tail -20'
Strategy:  cat strategy.md
Collab:    cat blackboard.md
Intervene: echo "CLAIM OPERATOR: ..." >> blackboard.md
Stop:      for i in $(seq 0 3); do screen -S ralph-agent$i -X quit; done
Collect:   tar czf results.tar.gz results.tsv strategy.md blackboard.md best/ done/ worktrees/*/memory/
Cleanup:   for i in $(seq 0 3); do git worktree remove --force worktrees/agent$i; done
```
