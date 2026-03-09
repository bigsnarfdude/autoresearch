# Trajectory Tracking — Round 9

## Agent Best Results (sorted)
| agent | best_bpb | steps | key config |
|-------|----------|-------|------------|
| agent4 | 1.0482 | 953 | depth=8 AR=96 MLP3x 2**17 mlr=0.04 wd=0.2 |
| agent2 | 1.0482 | 963 | depth=8 AR=96 MLP3x 2**17 mlr=0.04 wd=0.2 |
| agent6 | 1.0491 | 885 | depth=8 AR=96 MLP3x 2**17 mlr=0.04 wd=0.1 |
| agent5 | 1.0497 | 904 | depth=8 AR=96 MLP3x 2**17 mlr=0.03 wd=0.2 |
| agent3 | 1.0499 | 905 | depth=8 AR=96 MLP3x 2**17 mlr=0.04 warmdown=0.6 |
| agent7 | 1.0751 | 289 | depth=8 AR=96 MLP2x batch=64 |
| agent1 | 1.085 | - | various combos on 2**18 |
| agent0 | 1.123 | - | depth=10 AR=76 MLP2.5x |

## Progression of Global Best
| round | best_bpb | agent | key change |
|-------|----------|-------|------------|
| 1 | 1.133 | agent2 | TOTAL_BATCH_SIZE=2**18 |
| 2 | 1.098 | agent1 | RoPE 200K |
| 3 | 1.083 | agent6 | depth=10 + RoPE200K + init0.68 |
| 4 | 1.080 | agent2 | MLP 3x at depth=10 |
| 5 | 1.079 | agent2 | AR=76 depth=10 MLP3x |
| 6 | 1.076 | agent2 | depth=8 AR=96 MLP3x wd=0.2 |
| 7 | 1.075 | agent2 | + mlr=0.08 |
| 8 | 1.055 | agent4 | TOTAL_BATCH_SIZE=2**17 |
| 9 | 1.048 | agent2/agent4 | mlr=0.04 |

## Convergence Status
- **CONVERGED** at 1.048-1.050
- All agents at 2**17 produce near-identical results (within 0.002)
- Hyperparameter tuning space is exhausted (warmdown, mlr, wd all explored)
- Need structural/architectural changes to break through

## Key Insight: Batch Size was King
Batch size scaling accounted for ~0.085 of the ~0.132 total improvement:
- 2**19 → 2**18: -0.058 BPB
- 2**18 → 2**17: -0.020 BPB
- mlr tuning at 2**17: -0.007 BPB
