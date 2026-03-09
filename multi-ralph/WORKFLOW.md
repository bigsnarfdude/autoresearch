# Multi-Agent Research Workflow (Project Blackboard)

## Agent Lifecycle

```
IDLE → ASSIGNED → RUNNING → REPORTING → DONE
                    ↓
                  BLOCKED → (posts REQUEST to blackboard) → DONE
```

## Stopping Rules

An agent MUST stop and report when:
1. **Converged**: 3+ consecutive experiments with <1% improvement
2. **Blocked**: needs information or resources another agent has
3. **Refuted**: found evidence that contradicts the working hypothesis
4. **Budget exhausted**: hit max experiment count or time limit

An agent MUST NOT stop just because:
- One experiment failed (try a different approach)
- Results are surprising (investigate, don't bail)

## Blackboard Protocol

### Posting Format
```
CLAIM <agent>: <finding> (evidence: <experiment_id>, <metric>)
RESPONSE <agent> to <agent>: <agree|refute|extend> — <reasoning>
REQUEST <requester> to <target|any>: <what to test> (priority: <high|medium|low>)
DONE <agent>: <request_hash> — <result summary>
```

### Priority Rules
- **high**: blocks other agents' work (e.g., "need control experiment before interpreting results")
- **medium**: would improve collective understanding (e.g., "test monitoring differential")
- **low**: nice-to-have exploration (e.g., "try unusual persona combination")

### Conductor Dispatch
When `conductor.sh` is running, REQUEST lines with `to any` are automatically dispatched
to ephemeral agents. Requests addressed to specific agents are left for those agents.

## Architecture-Specific Rules

### vanilla (agent0)
- No memory, no collaboration
- Pure baseline for comparing agent designs
- Record everything in results.tsv only

### memory (agent1)
- Maintain `progress.md` (cumulative) and `next_ideas.md` (ranked queue)
- Re-rank ideas after every experiment
- If top 3 ideas all predict <2% improvement, switch to exploration

### blackboard (agent2)
- Post CLAIMs for any result that changes understanding
- Read all other agents' CLAIMs before designing next experiment
- Track prediction accuracy in `scratch/predictions.md`

### blackboard+judge (agent3)
- Review EVERY experiment before recording (judge/reviews/)
- Verdicts: keep / keep-but-suspicious / discard / retest-needed
- Run control experiments FIRST to establish false-positive floors
- If >50% of recent results are "suspicious", post blackboard alert

### supervisor (agent4)
- After every experiment, write `supervisor/oversight.md`
- Track dimension coverage: which areas explored vs unexplored
- Issue DIRECTIVES when agents are stuck or overlapping
- Monitor improvement rate — if flat for 5+ experiments across all agents, suggest paradigm shift

### debate-A/B (agent5/6)
- Write proposals and counter-proposals in `debate/current.md`
- Must resolve debate within 2 minutes (or proceed with original proposal)
- Archive completed debates to `debate/round_NNN.md`
- The challenger (B) should actively seek flaws, not just agree

### diversity (agent7)
- Optimize for COVERAGE, not peak performance
- Track which dimensions/combinations have been tried
- Specifically target gaps identified by supervisor
- Measure distance from existing corpus when possible

## Recording Results

All agents append to the same `results.tsv`:
```
commit<tab>score<tab>memory_gb<tab>status<tab>description<tab>agent<tab>design
```

- `status`: keep / discard / suspicious / retest
- Never overwrite — always append with `>>`
- If you beat the global best, update `best/` and `strategy.md`

## Escalation

If an agent discovers something that changes the fundamental approach:
1. Post a **high-priority CLAIM** to the blackboard
2. If running with conductor: post a **REQUEST to any** for validation
3. The supervisor agent (if running) should acknowledge within 1 round

## Safety

- Never modify shared state files atomically (risk of corruption with concurrent writes)
- Use append-only for results.tsv and blackboard.md
- Each agent owns its own memory/ and scratch/ directories exclusively
- Debate files are shared only between the debate pair
