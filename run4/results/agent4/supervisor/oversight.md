# Supervisor Oversight — Round 9

## Current Top 10 (sorted by BPB)
| agent | val_bpb | steps | description |
|-------|---------|-------|-------------|
| agent4 | 1.048167 | 953 | mlr=0.04 2**17 d8 AR=96 MLP3x wd=0.2 |
| agent2 | 1.048168 | 963 | mlr=0.04 2**17 d8 AR=96 MLP3x wd=0.2 |
| agent2 | 1.048214 | 924 | mlr=0.02 (no better than 0.04) |
| agent6 | 1.049106 | 885 | mlr=0.04 wd=0.1 (wd=0.1 close to 0.2) |
| agent5 | 1.049703 | 904 | mlr=0.03 (slightly worse than 0.04) |
| agent3 | 1.049858 | 905 | mlr=0.04 warmdown=0.6 |
| agent5 | 1.050077 | 903 | mlr=0.04 |
| agent5 | 1.050217 | 925 | mlr=0.02 |
| agent5 | 1.050459 | - | mlr=0.03 warmdown=0.4 |
| agent6 | 1.050606 | 869 | mlr=0.04 warmdown=0.6 |

## The Winning Recipe (Round 9)
Core: **depth=8, AR=96 (768-dim, 6 heads), MLP 3x, 2**17 batch, mlr=0.04, wd=0.2**
Plus: RoPE200K, init0.68x, warmdown=0.5, warmup=0.0
Result: 1.048 at ~950 steps, 84.9M params, 15.6GB VRAM

## Convergence Assessment
The field has CONVERGED at 1.048-1.050. All agents at 2**17 get nearly identical results.
- mlr=0.04 vs 0.02: identical (both 1.048)
- warmdown=0.4-0.6: all within 0.003 of each other
- wd=0.1 vs 0.2: within 0.001
- This suggests we are near the optimum for this architecture at this training budget.

## Confirmed Improvements (cumulative from baseline 1.18)
1. 2**17 batch: ~0.02 BPB over 2**18
2. 2**18 batch: ~0.06 BPB over 2**19
3. RoPE base 200K: ~0.08 BPB
4. AR=96 depth=8: ~0.08 BPB (width > depth)
5. MLP ratio 3x: ~0.01 BPB
6. Init scale 0.68x: ~0.008 BPB
7. mlr=0.04 at 2**17: ~0.008 BPB over 0.08
8. wd=0.2: ~0.002 BPB

## Confirmed Non-improvements at 2**17
- warmdown=0.4: 1.054 (WORSE)
- warmdown=0.6: 1.051 (WORSE)
- HEAD_DIM=64: 1.058 (WORSE, slower)
- wd=0.3: 1.055 (WORSE)
- wd=0.1: 1.049-1.051 (neutral/slightly worse)
- SSLL window: 1.055 (WORSE, slower)
- mlr=0.02: 1.048 (SAME as 0.04)
- mlr=0.03: 1.050 (slightly worse)
- SwiGLU MLP2x: 1.057 (WORSE, agent2)
- 2**16 batch: 1.068 (TOO NOISY)

## Under-explored Dimensions (HIGH PRIORITY)
1. **depth=9 at same width**: 1 extra layer, potentially faster convergence per step
2. **UNEMBEDDING_LR tuning**: 0.004 never tuned at 2**17, try 0.008 or 0.002
3. **EMBEDDING_LR tuning**: 0.6 never tuned at 2**17, try 0.3 or 0.9
4. **softcap tuning**: 15 is default, try 10 or 20
5. **MLP ratio 3.5x**: untested at 2**17 depth=8
6. **x0_lambda init**: 0.1 is default, what if 0.05 or 0.2?
7. **short_window size**: //8=256, what about //4=512 or //16=128?
8. **GQA**: n_kv_head=3 (GQA) to save params, use for more depth

## Agent Status (Round 9)
- agent0: behind, last result 1.12+
- agent1: 1.085 range, testing at 2**17
- agent2: TIED LEADER at 1.048, exhausting mlr/wd/warmdown grid
- agent3: 1.050 range, testing warmdown variants
- agent4 (me): TIED LEADER at 1.048, testing architecture changes
- agent5: 1.050 range, testing mlr/warmdown grid
- agent6: 1.049 with wd=0.1 (interesting), testing structural changes
- agent7: batch=64 regime, 1.075 best

## DIRECTIVES
1. **STOP** tuning warmdown/mlr/wd — the field has converged. The space between 0.4-0.6 warmdown, 0.02-0.06 mlr, 0.1-0.3 wd is fully explored.
2. **TRY** structural changes: depth=9, UNEMBEDDING_LR, EMBEDDING_LR, softcap, x0_lambda.
3. **agent0**: You're very far behind. Adopt 2**17 + mlr=0.04 + AR=96 + MLP3x immediately.
4. **agent7**: Try 2**17 batch with DEVICE_BATCH_SIZE=64 (grad_accum=1). Might give more steps than grad_accum=2.
5. **ALL**: Focus on dimensions that haven't been explored at 2**17.
