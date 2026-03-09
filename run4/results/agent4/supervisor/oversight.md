# Supervisor Oversight — Round 2

## Current Results (all agents, sorted by BPB)
| agent | val_bpb | description |
|-------|---------|-------------|
| agent1 | 1.098 | RoPE base 200K (GLOBAL BEST at 2**19!) |
| agent2 | 1.107397 | batch=2**18 + weight_decay=0.05 |
| agent2 | 1.108737 | batch=2**18 baseline |
| agent7 | 1.141499 | depth=8 batch=64 baseline |
| agent1 | 1.144 | default baseline |
| agent0 | 1.154624 | depth=10 aspect=64 |
| agent4 | 1.155614 | depth=10 matrix_lr=0.06 wd=0.05 |
| agent6 | 1.172475 | depth=8 baseline |
| agent4 | 1.179524 | baseline |
| agent0 | 1.179959 | baseline |
| agent3 | 1.183193 | baseline |
| agent5 | 1.186607 | baseline |

## Dimension Analysis
- **RoPE base**: MASSIVE win (agent1, 1.098). UNDER-EXPLORED — only 1 experiment. HIGH PRIORITY to combine with other wins.
- **Batch size (2**18)**: Confirmed win (agent2). But constrained agents can't use it.
- **Depth=10**: Confirmed win by 2 agents (agent0=1.154, agent4=1.155). ~0.025 BPB improvement.
- **Weight decay=0.05**: Helps on top of batch change (agent2, 1.107 vs 1.108). Small effect.
- **matrix_lr=0.06**: My test shows similar to agent0's depth=10, so the LR change is neutral at this depth.
- **HEAD_DIM=64**: UNTESTED
- **MLP ratio**: UNTESTED
- **Softcap**: UNTESTED
- **Warmdown tuning**: UNTESTED (known warmup hurts)

## Stuck Agents
- agent3, agent5, agent6: Still on baselines only. Need to start experimenting.

## Improvement Rate
- agent4: -0.024 BPB per experiment (1.179 → 1.155)
- agent2: -0.001 BPB per experiment after initial win
- agent1: -0.046 BPB in one experiment (RoPE base 200K)

## DIRECTIVES
1. **ALL AGENTS**: Try RoPE base 200K! This is the biggest single win found. Combine with your best config.
2. **Agent4 (me)**: Combine depth=10 + RoPE base 200K + wd=0.05
3. **Agents 3,5,6**: Stop running baselines and start experimenting!
4. **Agent2**: Try RoPE base 200K on top of 2**18 batch
5. **Under-explored**: HEAD_DIM=64, MLP ratio changes, softcap tuning
