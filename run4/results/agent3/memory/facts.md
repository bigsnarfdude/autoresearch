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

## Results
- Exp 001 (baseline): depth=8, val_bpb=1.183193, 184 steps, 11.7GB VRAM, 50.3M params
