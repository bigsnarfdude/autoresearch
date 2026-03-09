# Facts (Agent 3)

## Hardware
- GPU: NVIDIA A100-SXM4-40GB (CUDA_VISIBLE_DEVICES=3)
- Compute capability: 8.0 (Ampere, not Hopper)
- Uses kernels-community/flash-attn3 (not varunneal's)

## Baseline Config
- DEPTH=8, ASPECT_RATIO=64, HEAD_DIM=128
- model_dim = 512, n_head=4, n_kv_head=4
- TOTAL_BATCH_SIZE=2**19 (~524K tokens)
- DEVICE_BATCH_SIZE=32 (FIXED)
- TIME_BUDGET=300s, MAX_SEQ_LEN=2048
- MATRIX_LR=0.04, EMBEDDING_LR=0.6, UNEMBEDDING_LR=0.004
- WEIGHT_DECAY=0.2, WARMUP_RATIO=0.0, WARMDOWN_RATIO=0.5
- Activation: ReluSquared MLP
- Window pattern: SSSL

## Key Findings
- Depth=10 UNSTABLE and WORSE at 2**19 batch (not enough steps to converge)
- RoPE base=200000 is a big win (1.183→1.147 at depth=8)
- Stay with depth=8 at 2**19 batch

## Results
- Exp 001 (baseline): depth=8, base=10000, val_bpb=1.183193, 184 steps
- Exp 004 (new baseline): depth=8, base=200000, val_bpb=1.147283, 215 steps
- Exp 005: depth=10, base=200000: val_bpb=1.156591 (WORSE, unstable)
- Exp 006: +init0.68x: val_bpb=1.132935, 228 steps (KEEP)
- Exp 007: +mlr=0.08: val_bpb=1.127178, 225 steps (KEEP)
- Exp 008: warmdown=0.4: val_bpb=1.133067, 215 steps (DISCARD, worse at depth=8)
- Exp 009: ar=96 (768-dim): val_bpb=1.108382, 202 steps, 17.3GB (KEEP)
- Exp 010: +mlp_ratio=3.0: val_bpb=1.103629, 212 steps, 15.6GB (KEEP, current best)
