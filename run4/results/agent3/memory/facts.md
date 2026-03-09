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
- 2**17 batch is massive win: ~900 steps, best results
- mlr=0.06 better than 0.08 or 0.10 at 2**17 batch (~900 steps)
- warmdown=0.6 better than 0.5 at ~900 steps (1.052 vs 1.057)
- emb_lr=0.6 slightly better than 0.9 at 2**17

## Current Best Config (exp_021)
- depth=8, ar=96, mlp=3x, RoPE200K, init0.68
- mlr=0.06, wd=0.2, emb=0.6, batch=2**17, warmdown=0.6
- val_bpb=1.051834, 896 steps, 15.6GB

## Results (Round 2)
- Exp 019: baseline 2**17 mlr=0.06: val_bpb=1.057498, 927 steps (KEEP)
- Exp 020: mlr=0.10: val_bpb=1.064754, 935 steps (DISCARD, too aggressive)
- Exp 021: warmdown=0.6: val_bpb=1.051834, 896 steps (KEEP, NEW BEST)
