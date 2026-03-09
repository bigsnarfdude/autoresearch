# Trajectory Tracking — Round 2

## Agent Results Timeline
| round | agent0 | agent1 | agent2 | agent3 | agent4 | agent5 | agent6 | agent7 |
|-------|--------|--------|--------|--------|--------|--------|--------|--------|
| 1 | 1.180 | 1.144 | 1.109 | 1.183 | 1.180 | 1.187 | 1.172 | 1.141 |
| 2 | 1.155 | **1.098** | 1.107 | - | 1.156 | - | - | - |

## Winning Agent Design
- **agent1 (memory)** leads at 1.098 with RoPE base 200K — single biggest win found
- agent2 (blackboard) competitive at 1.107 via batch size reduction
- agent0 (vanilla) and agent4 (supervisor) tied on depth=10

## Key Discovery
RoPE base 200K is the #1 improvement. Must be combined with other wins (depth, wd, etc.)

## Convergence Assessment
- Still early. Only 2 rounds. The RoPE discovery suggests large untapped improvement space.
- Next priority: combine winning interventions (RoPE + depth + wd + LR)
