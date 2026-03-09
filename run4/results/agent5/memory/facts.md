# Agent 5 Facts

## Baseline Config (from best/train.py)
- DEPTH=8, ASPECT_RATIO=64
- model_dim=512, n_head=4, n_kv_head=4
- MATRIX_LR=0.04, EMBEDDING_LR=0.6, UNEMBEDDING_LR=0.004
- SCALAR_LR=0.5, WEIGHT_DECAY=0.2
- WARMUP_RATIO=0.0, WARMDOWN_RATIO=0.5
- WINDOW_PATTERN="SSSL"
- ADAM_BETAS=(0.8, 0.95)
- DEVICE_BATCH_SIZE=32, TOTAL_BATCH_SIZE=2**19
- Activation: ReluSquared MLP
- Optimizer: MuonAdamW (Muon for matrices, AdamW for embeddings/scalars)

## Results
| Round | Experiment | BPB | Steps | VRAM |
|-------|-----------|-----|-------|------|
| 1 | Baseline (depth=8, ar=64) | 1.1866 | 183 | 11.7GB |
| 2 | Depth=10 + RoPE200K | 1.1785 | 201 | 17.8GB |
| 3 | D10+mlr0.06+wd0.05+init0.68+RoPE200K | 1.1606 | 211 | 17.8GB |
| 4 | D8+mlr0.08+wd0.05+warmup0.05 (BEST) | 1.1459 | 230 | 11.7GB |
| 5 | D8+mlr0.10+wd0.05+softcap30 | 1.1549 | 221 | 11.7GB |
| 6 | D8+mlr0.08+wd0.05+softcap30 | 1.1580 | 217 | 11.7GB |
| 7 | D8+ar96+mlr0.08+wd0.05 (BEST) | 1.1262 | 218 | 17.3GB |
| 8 | D8+ar96+warmdown0.4 | 1.1362 | 207 | 17.3GB |

## Key Learnings
- Softcap=30 HURTS vs 15
- Matrix_lr=0.10 too aggressive, mlr=0.08 is sweet spot at depth=8
- ASPECT_RATIO=96 (width=768) beats depth=10 AND depth=8-ar64
- Warmdown=0.4 HURTS at depth=8 (confirmed by agent3 too). Stay at 0.5
- MLP_ratio=3x is new global best idea (agent2: 1.0799)
- My best: 1.1262 (depth=8, ar=96, mlr=0.08, wd=0.05, warmup=0.05)

## Cross-Agent Intel
- Agent2: MLP_ratio=3x depth=10 → 1.0799 (NEW GLOBAL BEST)
- Agent6: depth=10+RoPE200K+init0.68 → 1.084
- Agent7: depth=10+mlr=0.12+emb_lr=0.9 at batch=64 → 1.108
- Agent3: warmdown=0.4 hurts at depth=8 (1.133 vs 1.127)
