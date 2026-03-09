#!/bin/bash
# Ralph Loop: 1-solo run (50 iterations from baseline)
# Setup: bash ~/autoresearch/experiments/setup-experiment.sh 1-solo
# Launch: screen -dmS 1-solo bash ~/autoresearch/experiments/1-solo/ralph-loop/run.sh
# Check:  tail -f ~/autoresearch/experiments/1-solo/ralph-loop/loop.log
# Stop:   screen -S 1-solo -X quit

EXPDIR=~/autoresearch/experiments/1-solo
cd "$EXPDIR"
export PATH="$HOME/.local/bin:$PATH"

PROMPT='You are an autonomous AI researcher running experiment "1-solo".

WORKING DIRECTORY: '"$EXPDIR"'
You are already cd-ed here.

Read these files in order:
1. ralph-loop/program.md (full instructions)
2. ralph-loop/progress.md (current state and history)
3. ralph-loop/next_ideas.md (experiment queue)
4. train.py (the ONLY file you modify)
5. results.tsv (full log)

CRITICAL: This GPU has 16GB VRAM (RTX 4070 Ti SUPER), not 80GB.
Default DEVICE_BATCH_SIZE=128 WILL OOM. Fix before any run.

Run exactly ONE experiment:
1. Pick top idea from next_ideas.md (or establish baseline if first run)
2. Edit train.py
3. git add train.py && git commit -m "exp: <description>"
4. Run: source ~/.local/bin/env && timeout 700 uv run train.py > run.log 2>&1
5. Check: grep "^val_bpb:\|^peak_vram_mb:" run.log
6. If crash: tail -50 run.log. Fix if trivial else skip.
7. If improved: keep. If worse: revert train.py, git commit.
8. Append to results.tsv (tab-separated: commit val_bpb memory_gb status description)
9. Update progress.md and next_ideas.md with results and insights
10. git add and commit state updates

Then STOP. The wrapper calls you again with fresh context.'

MAX_ITERATIONS=50
iteration=0

while [ $iteration -lt $MAX_ITERATIONS ]; do
    iteration=$((iteration + 1))
    echo "=========================================="
    echo "1-SOLO ITERATION $iteration / $MAX_ITERATIONS"
    echo "TIME: $(date)"
    echo "=========================================="

    claude -p "$PROMPT" \
        --dangerously-skip-permissions \
        --max-turns 50

    exit_code=$?
    echo "Claude exited with code: $exit_code"
    echo "Completed iteration $iteration at $(date)"
    echo ""

    sleep 5
done

echo "=========================================="
echo "1-SOLO COMPLETE: $MAX_ITERATIONS iterations"
echo "TIME: $(date)"
echo "=========================================="
