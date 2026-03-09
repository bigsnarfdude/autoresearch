# Search Strategy — Run 4 (8 agents, 8 GPUs)

## UPDATED BY HUMAN OPERATOR — READ THIS FIRST

## Current best: 1.0466 (depth=8, AR=96, MLP3x, mlr=0.04, 2**17, wd=0.2, window="S", agent2, 945 steps)
## Default baseline: ~1.095 (355 steps solo, batch=32)
## 8-agent baseline: ~1.133 (213 steps, CPU/IO contention reduces steps)

## CRITICAL: Run 4 is DIFFERENT from Run 2
- Each agent has a DEDICATED GPU (not shared)
- But 8 agents cause CPU/IO contention → ~200-240 steps, not 355
- Old 'best' config (1.180) was tuned for 150-step contention regime
- Agent2 confirmed: triple combo gets 1.118 at 240 steps — WORSE than default 1.095 at 355
- RE-EVALUATE all hyperparameters for the ~220 step regime

## Hardware (Run 4)
- 8× A100 SXM4 40GB, 1 agent per GPU
- DEVICE_BATCH_SIZE = 32
- TOTAL_BATCH_SIZE = 2**19. You MAY change it — halving to 2**18 doubles your steps. This was the #1 win on the H100 leaderboard.
- BF16 native

## Run 4 results so far (AGENTS: APPEND YOUR RESULTS HERE)
| agent | experiment | val_bpb | steps | description |
|-------|-----------|---------|-------|-------------|
| agent1 | 018 | 1.126 | 227 | weight_decay=0.05 on best (x0+mlr+rope) |
| agent1 | 021 | 1.131 | 229 | muon_warmup=100 on best |
| agent6 | - | 1.133 | 208 | depth=9 aspect=56 (dim=512, 9 layers) |
| agent3 | - | 1.133 | 213 | concurrent baseline (default config) |
| agent5 | - | 1.157 | 216 | WARMUP_RATIO=0.1 on best config |
| agent2 | - | 1.118 | 240 | triple combo (x0+mlr0.08+rope50k) — worse than default |
| agent4 | - | - | - | HEAD_DIM=64 testing |
| agent2 | exp1 | 1.1087 | 395 | **NEW BEST** TOTAL_BATCH_SIZE=2**18 (halved batch) |
| agent1 | 002 | 1.098 | 463 | **NEW BEST** RoPE base 200K (less contention = more steps) |
| agent1 | 003 | 1.095 | 454 | **NEW BEST** init_scale=0.68 on RoPE200K |
| agent1 | 004 | 1.107 | 427 | discard: HEAD_DIM=64 hurts |
| agent1 | 005 | 1.085 | 483 | **NEW BEST** short_window=seq_len//8 on best |
| agent6 | - | 1.0834 | 388 | depth=10 RoPE200K init0.68 wd=0.05 (2**19) |
| agent2 | exp9 | 1.0799 | 431 | **NEW BEST** depth=10 MLP_ratio=3x 2**18 wd=0.05 |
| agent2 | exp12 | 1.0787 | 380 | **NEW BEST** depth=10 AR=76 MLP3x 2**18 wd=0.05 |

## What works (Run 4 confirmed)
- weight_decay=0.05 on best config: 1.126 (agent1, best so far)
- depth=9 at same width (aspect=56): 1.133 (agent6)

## Untested HIGH PRIORITY
- ~~TOTAL_BATCH_SIZE = 2**18~~ CONFIRMED: 1.1087, 395 steps (agent2) — NEW BEST
- HEAD_DIM = 64 (agent4 testing)
- GQA (n_kv_head < n_head)
- ~~MLP ratio changes~~ CONFIRMED: MLP 3x beats 4x at depth=10 (1.0799 vs 1.0855, agent2)
- scalar_lr tuning
- init scale (Karpathy found 0.68x was optimal)
- ~~RoPE base 200K~~ CONFIRMED: 1.098, 463 steps (agent1) — NEW BEST (but low contention)
- short_window = seq_len // 8

## What fails (avoid)
- matrix_lr=0.08 may be too aggressive for >200 steps (re-evaluate)
- warmup_ratio=0.05 hurts (agent4)
- warmdown > 0.5 catastrophic

## DIRECTIVE: All agents append results to this file AND to results.tsv

## UPDATE: TOTAL_BATCH_SIZE = 2**18 CONFIRMED BEST
Agent2 proved it: 2**18 gives 395 steps vs 213 at 2**19. Result: 1.109 vs 1.18 baseline.
ALL AGENTS: you MAY and SHOULD try TOTAL_BATCH_SIZE = 2**18. It is NOT locked.
This was the #1 win on the H100 leaderboard (Karpathy's 125-experiment run).

## OPERATOR UPDATE (latest) — ALL AGENTS READ THIS

### Current leaderboard (99 experiments):
1. agent2 (blackboard): **1.079** — depth=10 MLP3x AR=76 2**18 wd=0.05
2. agent1 (memory): 1.082 — depth=10 shortwin8 RoPE200K init0.68 2**18
3. agent6 (debate-B): 1.083 — depth=10 RoPE200K init0.68 wd=0.05
4. agent7 (bigbatch): 1.095 — depth=10 batch=64 MLP2.5x RoPE200K init0.68
5. agent5 (debate-A): 1.097 — depth=8 ar=96 mlp3x RoPE200K init0.68 mlr=0.08 wd=0.2 warmup=0
6. agent3 (judge): 1.104 — depth=8 ar=96 mlp3x RoPE200K init0.68 mlr=0.08 wd=0.2

### PRIORITY: FULL COMBINATION EXPERIMENT
Nobody has tried: depth=10 + MLP3x + 2**18 + RoPE200K + init0.68 + wd=0.05 + AR=76
This combines ALL winning changes. Try it.

### ALL AGENTS: TOTAL_BATCH_SIZE=2**18 IS UNLOCKED
If you were told otherwise, that was STALE. Your prompt says "You MAY change it."
