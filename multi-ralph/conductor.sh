#!/bin/bash
# conductor.sh — Symphony-inspired reactive dispatch for multi-agent research
#
# Instead of pre-assigning all experiments at launch, this watches the blackboard
# for REQUEST lines and spawns ephemeral agent runs to handle them.
#
# Pattern: blackboard.md gets REQUEST lines from running agents →
#          conductor picks them up → spawns a new agent in a worktree →
#          result flows back to blackboard + results.tsv
#
# Usage:
#   ./conductor.sh                     # watch shared blackboard, default config
#   ./conductor.sh --domain af         # use domains/af/ workflow
#   ./conductor.sh --dry-run           # print what would be dispatched
#
# Requires: git, claude CLI, screen

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SHARED_DIR="$REPO_DIR/multi-ralph"
CONDUCTOR_DIR="$SHARED_DIR/conductor"
POLL_INTERVAL="${POLL_INTERVAL:-30}"        # seconds between blackboard checks
MAX_CONCURRENT="${MAX_CONCURRENT:-4}"        # max ephemeral agents at once
DOMAIN="${DOMAIN:-}"                         # optional domain (af, compiler, etc.)
DRY_RUN=false

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain) DOMAIN="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --poll) POLL_INTERVAL="$2"; shift 2 ;;
        --max) MAX_CONCURRENT="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# Resolve paths
if [ -n "$DOMAIN" ]; then
    WORKFLOW="$SHARED_DIR/domains/$DOMAIN/WORKFLOW.md"
    BLACKBOARD="$SHARED_DIR/domains/$DOMAIN/blackboard.md"
else
    WORKFLOW="$SHARED_DIR/WORKFLOW.md"
    # Try run4 blackboard first, fall back to shared dir
    if [ -f "$REPO_DIR/run4/shared/blackboard.md" ]; then
        BLACKBOARD="$REPO_DIR/run4/shared/blackboard.md"
    else
        BLACKBOARD="$SHARED_DIR/blackboard.md"
    fi
fi

mkdir -p "$CONDUCTOR_DIR/dispatched" "$CONDUCTOR_DIR/log"

LOG="$CONDUCTOR_DIR/log/conductor_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "$(date '+%H:%M:%S') $*" | tee -a "$LOG"
}

# --- Blackboard Protocol ---
# Agents post:  REQUEST <requester> to <target>: <description>
# Conductor marks dispatched requests with: DISPATCHED <timestamp> <request_hash>
# When done, agent posts: DONE <request_hash>: <result summary>

get_pending_requests() {
    # Extract REQUEST lines not yet DISPATCHED
    if [ ! -f "$BLACKBOARD" ]; then
        return
    fi

    grep -n "^REQUEST " "$BLACKBOARD" 2>/dev/null | while IFS= read -r line; do
        line_num=$(echo "$line" | cut -d: -f1)
        content=$(echo "$line" | cut -d: -f2-)
        # Hash the content to track dispatch status
        hash=$(echo "$content" | md5 -q 2>/dev/null || echo "$content" | md5sum | cut -d' ' -f1)

        # Check if already dispatched
        if ! grep -q "DISPATCHED.*$hash" "$BLACKBOARD" 2>/dev/null && \
           ! [ -f "$CONDUCTOR_DIR/dispatched/$hash" ]; then
            echo "$hash|$line_num|$content"
        fi
    done
}

count_running_agents() {
    screen -ls 2>/dev/null | grep -c "conductor-agent" || echo 0
}

dispatch_request() {
    local hash="$1"
    local line_num="$2"
    local content="$3"

    if $DRY_RUN; then
        log "[DRY RUN] Would dispatch: $content"
        return
    fi

    # Mark as dispatched
    echo "$(date +%Y%m%d_%H%M%S)" > "$CONDUCTOR_DIR/dispatched/$hash"

    # Determine agent design from request content
    local design="ephemeral"
    case "$content" in
        *judge*|*review*|*confound*) design="judge" ;;
        *debate*|*challenge*|*counter*) design="debate" ;;
        *diverse*|*diversity*|*novel*) design="diversity" ;;
        *monitor*|*differential*) design="controlled" ;;
    esac

    # Create ephemeral worktree
    local branch="conductor/req-${hash:0:8}"
    local tree="$REPO_DIR/worktrees/conductor-${hash:0:8}"

    git -C "$REPO_DIR" branch -D "$branch" 2>/dev/null || true
    if [ -d "$tree" ]; then
        git -C "$REPO_DIR" worktree remove --force "$tree" 2>/dev/null || rm -rf "$tree"
    fi
    git -C "$REPO_DIR" worktree add -b "$branch" "$tree" HEAD

    # Symlink shared state
    rm -rf "$tree/multi-ralph" && ln -sfn "$SHARED_DIR" "$tree/multi-ralph"
    [ -d "$REPO_DIR/run4" ] && ln -sfn "$REPO_DIR/run4" "$tree/run4"

    # Build prompt from WORKFLOW.md + request
    local prompt=""
    if [ -f "$WORKFLOW" ]; then
        prompt="$(cat "$WORKFLOW")\n\n"
    fi
    prompt="${prompt}You are an EPHEMERAL agent spawned by the conductor to handle this request:\n\n"
    prompt="${prompt}${content}\n\n"
    prompt="${prompt}Design: ${design}\n\n"
    prompt="${prompt}PROTOCOL:\n"
    prompt="${prompt}1. Read the blackboard and results.tsv for context\n"
    prompt="${prompt}2. Execute the requested experiment or analysis\n"
    prompt="${prompt}3. Record results in results.tsv\n"
    prompt="${prompt}4. Post your findings to the blackboard as a CLAIM or RESPONSE\n"
    prompt="${prompt}5. When done, write DONE to the blackboard referencing the original REQUEST\n"
    prompt="${prompt}6. Exit when the task is complete (do NOT loop forever)\n\n"
    prompt="${prompt}Blackboard: $(basename "$BLACKBOARD")\n"
    prompt="${prompt}Results: multi-ralph/results.tsv\n"

    # Write prompt and runner
    echo -e "$prompt" > "$tree/.agent-prompt.txt"

    cat > "$tree/.run-conductor-agent.sh" << RUNNER
#!/bin/bash
cd "$tree"
echo "\$(date): conductor agent ${hash:0:8} starting (design=$design)" >> agent.log

claude -p "\$(cat .agent-prompt.txt)" \\
    --dangerously-skip-permissions \\
    --max-turns 50 \\
    2>> agent.log || true

echo "\$(date): conductor agent ${hash:0:8} finished" >> agent.log

# Signal completion
echo "DONE ${hash:0:8}" >> "$CONDUCTOR_DIR/log/completions.log"
RUNNER
    chmod +x "$tree/.run-conductor-agent.sh"

    # Launch in screen
    local session="conductor-agent-${hash:0:8}"
    screen -dmS "$session" "$tree/.run-conductor-agent.sh"

    log "DISPATCHED: $content → $session (design=$design)"
}

cleanup_finished() {
    # Remove worktrees for completed ephemeral agents
    for done_file in "$CONDUCTOR_DIR"/dispatched/*; do
        [ -f "$done_file" ] || continue
        local hash=$(basename "$done_file")
        local session="conductor-agent-${hash:0:8}"

        # Check if screen session still exists
        if ! screen -ls 2>/dev/null | grep -q "$session"; then
            local tree="$REPO_DIR/worktrees/conductor-${hash:0:8}"
            if [ -d "$tree" ]; then
                git -C "$REPO_DIR" worktree remove --force "$tree" 2>/dev/null || true
                log "CLEANUP: removed worktree for $hash"
            fi
        fi
    done
}

# --- Main Loop ---

log "=== Conductor started ==="
log "Blackboard: $BLACKBOARD"
log "Workflow:   ${WORKFLOW:-none}"
log "Poll:       ${POLL_INTERVAL}s"
log "Max agents: $MAX_CONCURRENT"
log ""

if $DRY_RUN; then
    log "[DRY RUN MODE — no agents will be spawned]"
fi

while true; do
    # Count running agents
    running=$(count_running_agents)

    # Get pending requests
    pending=$(get_pending_requests)

    if [ -n "$pending" ]; then
        echo "$pending" | while IFS='|' read -r hash line_num content; do
            [ -z "$hash" ] && continue

            if [ "$running" -ge "$MAX_CONCURRENT" ]; then
                log "QUEUED (${running}/${MAX_CONCURRENT} running): $content"
                continue
            fi

            dispatch_request "$hash" "$line_num" "$content"
            running=$((running + 1))
        done
    fi

    # Cleanup finished agents
    cleanup_finished

    sleep "$POLL_INTERVAL"
done
