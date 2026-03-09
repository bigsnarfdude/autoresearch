#!/bin/bash
# Run 4: 8 agents, 8 GPUs, 4 cognitive architectures
# researchRalph v2 — LLM as Optimizer experiment
#
# Usage: ./multi-ralph/launch-8gpu.sh
#
# Prerequisites:
#   1. git clone https://github.com/bigsnarfdude/autoresearch.git && cd autoresearch
#   2. uv sync && uv run prepare.py
#   3. Claude Code installed and authenticated
#   4. 8 GPUs visible in nvidia-smi

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

NUM_AGENTS=8
SHARED_DIR="$REPO_DIR/multi-ralph"
WORKTREE_DIR="$REPO_DIR/worktrees"
RUN4_DIR="$REPO_DIR/run4"

echo "=== researchRalph v2 — Run 4: 8 agents, 8 GPUs ==="
echo "Repo:      $REPO_DIR"
echo "Shared:    $SHARED_DIR"
echo ""

# --- Check GPUs ---
GPU_COUNT=$(nvidia-smi -L | wc -l)
echo "GPUs detected: $GPU_COUNT"
if [ "$GPU_COUNT" -lt 8 ]; then
    echo "WARNING: Only $GPU_COUNT GPUs found. Agents will double up."
fi
echo ""

# --- Initialize run4 directory ---

mkdir -p "$RUN4_DIR/shared" "$RUN4_DIR/results"
mkdir -p "$SHARED_DIR/queue" "$SHARED_DIR/active" "$SHARED_DIR/done" "$SHARED_DIR/best"
rm -f "$SHARED_DIR/queue/"*.md "$SHARED_DIR/active/"*.md

# Copy train.py as starting point
cp "$REPO_DIR/train.py" "$SHARED_DIR/best/train.py"

# Initialize results.tsv
printf 'commit\tval_bpb\tmemory_gb\tstatus\tdescription\tagent\tdesign\n' > "$SHARED_DIR/results.tsv"

# Initialize shared blackboard for agents 2-5
cat > "$RUN4_DIR/shared/blackboard.md" << 'EOF'
# Shared Blackboard (Agents 2-5)

Format: append claims, responses, and requests below.

## Claims
<!-- Agent posts a finding: "CLAIM agent2: matrix LR 0.08 helps at depth 8 (1.179 vs 1.193)" -->

## Responses
<!-- Agent responds to a claim: "RESPONSE agent3 to agent2: confirmed at depth 5 too (1.158 vs 1.172)" -->
<!-- Or refutes: "REFUTE agent3: matrix LR 0.08 does NOT help at depth 12 (1.542 vs 1.540)" -->

## Requests
<!-- Agent asks another to test something: "REQUEST agent2 to agent3: test LR 0.12 at depth 5" -->
EOF

# --- Create worktrees ---

mkdir -p "$WORKTREE_DIR"

for AGENT in $(seq 0 $((NUM_AGENTS - 1))); do
    BRANCH="run4/agent${AGENT}"
    TREE="$WORKTREE_DIR/agent${AGENT}"

    if [ -d "$TREE" ]; then
        git worktree remove --force "$TREE" 2>/dev/null || rm -rf "$TREE"
    fi
    git branch -D "$BRANCH" 2>/dev/null || true

    echo "Creating worktree agent${AGENT}..."
    git worktree add -b "$BRANCH" "$TREE" HEAD

    ln -sfn "$SHARED_DIR" "$TREE/multi-ralph"
    ln -sfn "$RUN4_DIR" "$TREE/run4"
    touch "$TREE/run.log"
done

echo ""
echo "=== Writing agent programs ==="
echo ""

# --- Agent 0: Vanilla (control) ---
cat > "$WORKTREE_DIR/agent0/.agent-prompt.txt" << 'AGENTEOF'
You are agent 0 — the VANILLA CONTROL in a multi-agent experiment.

DESIGN: No memory. No strategy file. Just results.tsv and your own judgment.

PROTOCOL:
1. Read train.py to understand the codebase
2. Run baseline: CUDA_VISIBLE_DEVICES=0 uv run train.py > run.log 2>&1
3. Check val_bpb in run.log (look for "val_bpb")
4. Record in multi-ralph/results.tsv: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent0<tab>vanilla
5. Think about what to change. Edit train.py.
6. Run again. Compare. Keep or revert.
7. Repeat forever.

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=0 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 32. NEVER change this.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- Max depth: 10.
- Always start from: cp multi-ralph/best/train.py train.py
- You have NO memory files. Each round you only see results.tsv.
- Append results with >> (never overwrite results.tsv)
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

# --- Agent 1: Single-ralph (memory) ---
cat > "$WORKTREE_DIR/agent1/.agent-prompt.txt" << 'AGENTEOF'
You are agent 1 — the SINGLE-RALPH MEMORY agent in a multi-agent experiment.

DESIGN: Full persistent memory. You maintain progress.md and next_ideas.md.

PROTOCOL:
1. Read multi-ralph/program-multi.md for the protocol
2. If progress.md doesn't exist, run baseline first
3. Read progress.md and next_ideas.md for your current state
4. Pick the top experiment from next_ideas.md
5. cp multi-ralph/best/train.py train.py
6. Apply changes, run: CUDA_VISIBLE_DEVICES=1 uv run train.py > run.log 2>&1
7. Check val_bpb. Keep or discard.
8. Update progress.md with: experiment number, what changed, result, insight
9. Update next_ideas.md: re-rank based on what you learned
10. Record in multi-ralph/results.tsv: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent1<tab>memory
11. If you beat the global best in multi-ralph/strategy.md, update multi-ralph/best/train.py
12. Repeat forever.

YOUR MEMORY FILES (create if missing):
- progress.md: cumulative experiment history, strategic insights, current best config
- next_ideas.md: ranked queue of 5-10 experiment ideas, re-ranked after each result

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=1 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 32. NEVER change this.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- Max depth: 10.
- Always start from: cp multi-ralph/best/train.py train.py
- Append results with >> (never overwrite results.tsv)
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

# --- Agent 2: Blackboard + Structured Memory ---
cat > "$WORKTREE_DIR/agent2/.agent-prompt.txt" << 'AGENTEOF'
You are agent 2 — the BLACKBOARD agent in a multi-agent experiment.

DESIGN: Structured memory (facts/failures/hunches) + shared blackboard with agents 3-5 + prediction tracking.

PROTOCOL:
1. Read multi-ralph/program-multi.md for the base protocol
2. Read run4/shared/blackboard.md for claims from other agents
3. Read your memory files (create if missing)
4. Read your scratch/predictions.md — how accurate were your last predictions?
5. Write your hypothesis and predicted outcome in scratch/hypothesis.md BEFORE running
6. cp multi-ralph/best/train.py train.py
7. Apply changes, run: CUDA_VISIBLE_DEVICES=2 uv run train.py > run.log 2>&1
8. Check val_bpb. Compare to your prediction. Record prediction error.
9. Update memory:
   - If result confirms something: add to memory/facts.md
   - If result shows something doesn't work: add to memory/failures.md
   - If result suggests something untested: add to memory/hunches.md
10. Post to run4/shared/blackboard.md:
    - CLAIM if you found something noteworthy
    - RESPONSE if another agent's claim is confirmed/refuted by your result
    - REQUEST if you want another agent to test something
11. Record in multi-ralph/results.tsv: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent2<tab>blackboard
12. Update scratch/predictions.md with actual vs predicted
13. If you beat the global best, update multi-ralph/best/train.py and multi-ralph/strategy.md
14. Repeat forever.

YOUR FILES (create if missing):
- memory/facts.md: confirmed findings (e.g., "LR 0.08 > 0.04, confirmed 2 runs")
- memory/failures.md: dead ends — NEVER retry these (e.g., "depth 12 = catastrophic at 5 min budget")
- memory/hunches.md: suspicions to test (e.g., "x0_lambda might interact with depth")
- scratch/hypothesis.md: current theory + what you're testing and why
- scratch/predictions.md: predicted vs actual val_bpb for each experiment

SHARED FILE (read AND write):
- run4/shared/blackboard.md: shared with agents 3, 4, 5

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=2 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 32. NEVER change this.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- Max depth: 10.
- Always start from: cp multi-ralph/best/train.py train.py
- Append results with >> (never overwrite results.tsv)
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

# --- Agent 3: Blackboard + Judge ---
cat > "$WORKTREE_DIR/agent3/.agent-prompt.txt" << 'AGENTEOF'
You are agent 3 — the BLACKBOARD + JUDGE agent in a multi-agent experiment.

DESIGN: Same as agent 2 (structured memory + blackboard + predictions) PLUS self-review after each experiment.

PROTOCOL:
Same as agent 2 (structured memory, blackboard, predictions), but after step 8, add:

JUDGE STEP (do this after EVERY experiment):
Before marking keep/discard, review your own result:
- Write a review in judge/reviews/exp_NNN.md answering:
  a. Did I change only ONE thing? If not, the result is CONFOUNDED.
  b. Is the improvement bigger than noise? (Step counts vary ±10%. A 0.001 BPB difference at 170 steps could be noise.)
  c. Is the step count comparable to the baseline? (If baseline got 355 steps and this got 280, not fair.)
  d. Could GPU contention explain the difference? (Check if other agents were compiling simultaneously.)
  e. VERDICT: keep / keep-but-confounded / discard / retest-needed
- Only mark "keep" if the verdict is clean.
- If "retest-needed", add to memory/hunches.md for later.

Record in multi-ralph/results.tsv: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent3<tab>blackboard+judge

YOUR FILES (create if missing):
- memory/facts.md, memory/failures.md, memory/hunches.md (same as agent 2)
- scratch/hypothesis.md, scratch/predictions.md (same as agent 2)
- judge/reviews/exp_NNN.md (one per experiment — the self-review)

SHARED FILE: run4/shared/blackboard.md (shared with agents 2, 4, 5)

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=3 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 32. NEVER change this.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- Max depth: 10.
- Always start from: cp multi-ralph/best/train.py train.py
- Append results with >> (never overwrite results.tsv)
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

# --- Agent 4: Supervisor (reads all, directs strategy) ---
cat > "$WORKTREE_DIR/agent4/.agent-prompt.txt" << 'AGENTEOF'
You are agent 4 — the SUPERVISOR agent in a multi-agent experiment.

DESIGN: You train AND supervise. Between your own experiments, you review all agents' work and write strategic directives.

PROTOCOL:
1. Run your own experiments like agent 2 (structured memory, blackboard, predictions)
2. After EVERY experiment, do a supervisor review:
   a. Read multi-ralph/results.tsv — ALL results from ALL agents
   b. Read run4/shared/blackboard.md — all claims and responses
   c. Write supervisor/oversight.md:
      - Which dimensions are well-explored? (>3 experiments, diminishing returns)
      - Which dimensions are under-explored? (<2 experiments)
      - Are any agents stuck in a local minimum? (>3 experiments in same dimension with no improvement)
      - What's the improvement rate? (BPB delta per experiment, rolling 5)
      - DIRECTIVES: suggestions for what agents should try next (they can read this file)
   d. Write supervisor/trajectory.md:
      - Improvement rate by round for each agent
      - Which agent design is winning?
      - Overall convergence assessment

3. Post to run4/shared/blackboard.md with supervisor observations
4. Record in multi-ralph/results.tsv: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent4<tab>supervisor

YOUR FILES (create if missing):
- memory/facts.md, memory/failures.md, memory/hunches.md
- scratch/hypothesis.md, scratch/predictions.md
- supervisor/oversight.md: strategic directives for all agents
- supervisor/trajectory.md: convergence tracking

SHARED FILE: run4/shared/blackboard.md (shared with agents 2, 3, 5)

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=4 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 32. NEVER change this.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- Max depth: 10.
- Always start from: cp multi-ralph/best/train.py train.py
- Append results with >> (never overwrite results.tsv)
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

# --- Agent 5: Debate partner A ---
cat > "$WORKTREE_DIR/agent5/.agent-prompt.txt" << 'AGENTEOF'
You are agent 5 — DEBATE PARTNER A in a multi-agent experiment.

DESIGN: You and agent 6 share a debate file. Before each experiment, you write your argument for what to test next. After agent 6 responds (or after 2 minutes), you resolve the debate and run the experiment.

PROTOCOL:
1. Read multi-ralph/results.tsv and run4/shared/blackboard.md for context
2. Read memory files (structured, same as agent 2)
3. DEBATE STEP:
   a. Write to debate/current.md:
      "AGENT5 PROPOSES: [experiment] BECAUSE [reasoning] EXPECTED: [predicted BPB]"
   b. Wait up to 2 minutes for agent 6 to respond in the same file
   c. If agent 6 responds with agreement: run your proposed experiment
   d. If agent 6 responds with counter-proposal: consider it. Write your resolution.
   e. If no response after 2 min: run your proposal anyway
4. cp multi-ralph/best/train.py train.py
5. Apply changes, run: CUDA_VISIBLE_DEVICES=5 uv run train.py > run.log 2>&1
6. Record result in debate/current.md: "RESULT: [actual BPB] vs predicted [predicted BPB]"
7. Update memory, blackboard, results.tsv (same as agent 2)
8. Record: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent5<tab>debate-A
9. Move debate/current.md to debate/round_NNN.md
10. Repeat forever.

YOUR FILES (create if missing):
- memory/facts.md, memory/failures.md, memory/hunches.md
- scratch/hypothesis.md, scratch/predictions.md
- debate/current.md: active debate with agent 6
- debate/round_NNN.md: archived debates

SHARED FILES:
- run4/shared/blackboard.md (shared with agents 2, 3, 4)
- debate/current.md (shared with agent 6 ONLY)

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=5 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 32. NEVER change this.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- Max depth: 10.
- Always start from: cp multi-ralph/best/train.py train.py
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

# --- Agent 6: Debate partner B ---
cat > "$WORKTREE_DIR/agent6/.agent-prompt.txt" << 'AGENTEOF'
You are agent 6 — DEBATE PARTNER B in a multi-agent experiment.

DESIGN: You and agent 5 share a debate file. You respond to agent 5's proposals with agreement, counter-proposals, or refinements. Then you run your OWN experiment (possibly different from agent 5's).

PROTOCOL:
1. Read multi-ralph/results.tsv and run4/shared/blackboard.md for context
2. Read memory files (structured, same as agent 2)
3. DEBATE STEP:
   a. Check debate/current.md for agent 5's latest proposal
   b. If agent 5 has proposed something, respond:
      "AGENT6 RESPONDS: [agree/counter/refine] BECAUSE [reasoning]"
      "AGENT6 WILL RUN: [your own experiment] EXPECTED: [predicted BPB]"
   c. If no proposal from agent 5: write your own proposal and proceed
4. cp multi-ralph/best/train.py train.py
5. Apply YOUR experiment (may differ from agent 5's), run: CUDA_VISIBLE_DEVICES=6 uv run train.py > run.log 2>&1
6. Record result in debate/current.md
7. Update memory, blackboard, results.tsv (same as agent 2)
8. Record: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent6<tab>debate-B
9. Repeat forever.

KEY: You are the CHALLENGER. If agent 5 proposes something you think is wrong, say so and explain why. Productive disagreement leads to better experiments. But always run SOMETHING — don't just debate.

YOUR FILES (create if missing):
- memory/facts.md, memory/failures.md, memory/hunches.md
- scratch/hypothesis.md, scratch/predictions.md
- debate/current.md: active debate with agent 5 (SHARED)

SHARED FILES:
- run4/shared/blackboard.md (shared with agents 2, 3, 4)
- debate/current.md (shared with agent 5 ONLY)

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=6 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 32. NEVER change this.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- Max depth: 10.
- Always start from: cp multi-ralph/best/train.py train.py
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

# --- Agent 7: Big batch explorer ---
cat > "$WORKTREE_DIR/agent7/.agent-prompt.txt" << 'AGENTEOF'
You are agent 7 — the BIG BATCH EXPLORER in a multi-agent experiment.

DESIGN: Same structured memory as agent 2, but you run at DEVICE_BATCH_SIZE=64 instead of 32. You get fewer steps but more gradient per step. You are testing whether the "throughput > capacity" finding holds at larger batch.

IMPORTANT: You are the ONLY agent allowed to use batch=64. You have a dedicated GPU with no contention, so 64 is safe (~25GB on 40GB GPU). The other 7 agents use batch=32.

PROTOCOL:
1. Read multi-ralph/program-multi.md for the base protocol
2. Read memory files and blackboard (same as agent 2)
3. cp multi-ralph/best/train.py train.py
4. ALWAYS set DEVICE_BATCH_SIZE = 64 in train.py before running
5. Run: CUDA_VISIBLE_DEVICES=7 uv run train.py > run.log 2>&1
6. Record in results.tsv with description noting "batch=64"
7. Record: commit<tab>val_bpb<tab>memory_gb<tab>status<tab>description<tab>agent7<tab>bigbatch
8. Compare your results to agents 0-6 (batch=32). Note:
   - You get different step counts (fewer steps, bigger batch = same tokens)
   - Your baseline will differ from theirs
   - Compare relative improvement, not absolute BPB
9. SPECIAL MISSION: Try larger models (depth 10, 12) that fail at batch=32.
   At batch=64 you get ~250 steps. Depth 10-12 might get ~150 steps.
   Test whether bigger models help when batch is bigger.
10. Update memory, blackboard, results.tsv
11. Repeat forever.

YOUR FILES (create if missing):
- memory/facts.md, memory/failures.md, memory/hunches.md
- scratch/hypothesis.md, scratch/predictions.md

SHARED FILE: run4/shared/blackboard.md (read-only — post your findings but focus on your own search)

CONSTRAINTS:
- CUDA_VISIBLE_DEVICES=7 (your dedicated GPU)
- DEVICE_BATCH_SIZE = 64. This is YOUR setting. Other agents use 32.
- TOTAL_BATCH_SIZE = 2**19. NEVER change this.
- You CAN test depth > 10 (you have headroom). Try depth 12, 14 if you want.
- Always start from: cp multi-ralph/best/train.py train.py (then change batch to 64)
- Do not stop. Do not ask questions. Run experiments forever.
AGENTEOF

echo ""
echo "=== Creating agent subdirectories ==="

for AGENT in 2 3 4 5 6 7; do
    TREE="$WORKTREE_DIR/agent${AGENT}"
    mkdir -p "$TREE/memory" "$TREE/scratch"
done

mkdir -p "$WORKTREE_DIR/agent3/judge/reviews"
mkdir -p "$WORKTREE_DIR/agent4/supervisor"
mkdir -p "$WORKTREE_DIR/agent5/debate"
mkdir -p "$WORKTREE_DIR/agent6/debate"

# Symlink shared debate directory so both agents see the same file
ln -sfn "$WORKTREE_DIR/agent5/debate" "$WORKTREE_DIR/agent6/debate"

echo ""
echo "=== Writing runner scripts ==="

for AGENT in $(seq 0 $((NUM_AGENTS - 1))); do
    TREE="$WORKTREE_DIR/agent${AGENT}"
    GPU=$AGENT
    # If fewer than 8 GPUs, wrap around
    if [ "$GPU_COUNT" -lt 8 ]; then
        GPU=$((AGENT % GPU_COUNT))
    fi

    cat > "$TREE/.run-agent.sh" << RUNNER_EOF
#!/bin/bash
AGENT_ID=$AGENT
TREE_DIR="$TREE"
cd "\$TREE_DIR"
export CUDA_VISIBLE_DEVICES=$GPU

ROUND=0
while true; do
    ROUND=\$((ROUND + 1))
    echo "\$(date): agent \$AGENT_ID starting round \$ROUND (GPU $GPU)" >> agent.log

    claude -p "\$(cat .agent-prompt.txt)

This is round \$ROUND. Check multi-ralph/results.tsv for latest state from all agents. Continue the experiment loop." \\
        --dangerously-skip-permissions \\
        --max-turns 200 \\
        2>> agent.log || true

    echo "\$(date): agent \$AGENT_ID claude exited round \$ROUND, restarting in 5s..." >> agent.log
    sleep 5
done
RUNNER_EOF
    chmod +x "$TREE/.run-agent.sh"
done

echo ""
echo "=== Launching 8 agents (staggered 30s apart) ==="
echo ""

for AGENT in $(seq 0 $((NUM_AGENTS - 1))); do
    TREE="$WORKTREE_DIR/agent${AGENT}"
    SESSION="ralph-agent${AGENT}"
    GPU=$AGENT
    if [ "$GPU_COUNT" -lt 8 ]; then
        GPU=$((AGENT % GPU_COUNT))
    fi

    DESIGNS=("vanilla" "memory" "blackboard" "blackboard+judge" "supervisor" "debate-A" "debate-B" "bigbatch")

    screen -S "$SESSION" -X quit 2>/dev/null || true
    screen -dmS "$SESSION" "$TREE/.run-agent.sh"

    echo "  Agent $AGENT: GPU=$GPU design=${DESIGNS[$AGENT]} screen=$SESSION"

    # Stagger launches by 30 seconds
    if [ "$AGENT" -lt $((NUM_AGENTS - 1)) ]; then
        echo "    (waiting 30s before next agent...)"
        sleep 30
    fi
done

echo ""
echo "=== All 8 agents launched ==="
echo ""
echo "AGENT DESIGNS:"
echo "  Agent 0 (GPU 0): Vanilla — no memory, control group"
echo "  Agent 1 (GPU 1): Single-ralph — progress.md persistent memory"
echo "  Agent 2 (GPU 2): Blackboard — structured memory + shared claims + predictions"
echo "  Agent 3 (GPU 3): Blackboard + Judge — adds self-review for confounds"
echo "  Agent 4 (GPU 4): Supervisor — trains + writes strategic oversight for all"
echo "  Agent 5 (GPU 5): Debate A — proposes experiments, debates with agent 6"
echo "  Agent 6 (GPU 6): Debate B — challenges agent 5, runs own experiments"
echo "  Agent 7 (GPU 7): Big Batch — batch=64, tests larger models + capacity"
echo ""
echo "Monitor:"
echo "  screen -ls                                    # list sessions"
echo "  screen -r ralph-agent0                        # attach (Ctrl+A D to detach)"
echo "  cat multi-ralph/results.tsv                   # all results"
echo "  cat run4/shared/blackboard.md                 # agent collaboration"
echo "  cat worktrees/agent4/supervisor/oversight.md  # strategic overview"
echo "  cat worktrees/agent5/debate/current.md        # debate in progress"
echo "  ls worktrees/agent3/judge/reviews/            # judge reviews"
echo "  watch -n 5 nvidia-smi                         # GPU utilization"
echo ""
echo "Quick dashboard:"
echo "  watch -n 30 'echo \"=== RESULTS ===\"; cat multi-ralph/results.tsv | tail -20; echo; echo \"=== BLACKBOARD ===\"; tail -10 run4/shared/blackboard.md; echo; echo \"=== SUPERVISOR ===\"; tail -10 worktrees/agent4/supervisor/oversight.md 2>/dev/null'"
echo ""
echo "Stop:"
echo "  for i in \$(seq 0 7); do screen -S ralph-agent\$i -X quit; done"
echo ""
echo "Collect data:"
echo "  cp multi-ralph/results.tsv run4/results/final.tsv"
echo "  for i in \$(seq 0 7); do cp -r worktrees/agent\$i/memory run4/results/agent\${i}_memory 2>/dev/null; done"
echo "  for i in \$(seq 0 7); do cp -r worktrees/agent\$i/scratch run4/results/agent\${i}_scratch 2>/dev/null; done"
echo "  cp -r worktrees/agent3/judge run4/results/agent3_judge"
echo "  cp -r worktrees/agent4/supervisor run4/results/agent4_supervisor"
echo "  cp -r worktrees/agent5/debate run4/results/debate_archive"
echo "  cp run4/shared/blackboard.md run4/results/blackboard_final.md"
echo ""
echo "Cleanup:"
echo "  for i in \$(seq 0 7); do git worktree remove --force worktrees/agent\$i; done"
