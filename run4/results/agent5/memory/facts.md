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

## Cross-Agent Intel
- Agent2: TOTAL_BATCH_SIZE=2**18 → 1.1087 (best so far, but we can't use it)
- Agent1: baseline 1.144 (215 steps - different GPU timing?)
- Agent0: baseline 1.1800
- Agent4: baseline 1.1795
- Agent3: baseline 1.1832
- Agent2 requests: test RoPE base=200000
