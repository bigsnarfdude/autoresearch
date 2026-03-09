# Experiment Progress

## Current State

- **Best val_bpb**: 1.150405
- **Best commit**: bdf134f
- **Baseline val_bpb**: 1.192676
- **Total improvement**: -0.042271 (-3.5%)
- **Experiments run**: 36

## GPU Environment

- **GPU**: NVIDIA RTX 4070 Ti SUPER (16GB VRAM)
- **Server**: nigel.birs.ca
- **Max DEVICE_BATCH_SIZE**: 32 (at depth=5).
- **Working dir**: ~/autoresearch/
- **Run command**: `source ~/.local/bin/env && cd ~/autoresearch && timeout 700 uv run train.py > run.log 2>&1`
- **Steps per 5min**: ~358 (at depth=5, batch=32)
- **MFU**: ~6.7%

## Current Best Hyperparameters

```
DEPTH = 5
DEVICE_BATCH_SIZE = 32
ASPECT_RATIO = 64       # model_dim = 384 (3 heads of 128)
HEAD_DIM = 128
MATRIX_LR = 0.08
EMBEDDING_LR = 1.2
UNEMBEDDING_LR = 0.008
SCALAR_LR = 1.0
WEIGHT_DECAY = 0.2
WARMUP_RATIO = 0.0
WARMDOWN_RATIO = 0.3 (cosine shape)
FINAL_LR_FRAC = 0.2
ADAM_BETAS = (0.8, 0.95)
TOTAL_BATCH_SIZE = 2**19
WINDOW_PATTERN = "S" (last layer forced long)
softcap = 8
Muon momentum warmup: 0.85→0.95 over 100 steps
LR warmdown: cosine curve
```

## Strategic Insights

### What works on this GPU
- **Smaller models, more steps**: Depth 5 >> 6 >> 8. Speed > capacity.
- **Higher LRs**: All defaults need ~2x for ~358-step regime.
- **Non-zero final LR**: FINAL_LR_FRAC=0.2.
- **Warmdown 0.3**: Sweet spot.
- **All-short windows**: Pattern "S" (last layer auto-long).
- **Tighter softcap**: 15→10→8 each improved. 6 was too tight.
- **Faster momentum warmup**: 300→100 steps (was wasting most of training in warmup).
- **Cosine warmdown**: Marginal but free improvement over linear.

### What fails
- Warmup, deeper models, wider models, SwiGLU, larger/smaller batches, higher weight decay, all-long windows, softcap 6, softcap 30.

### Remaining ideas (diminishing returns territory)
- Remove value embeddings (speed simplification)
- Remove x0 residual (x0_lambdas 0.2 was worse, maybe 0.0 helps?)
- Embedding tying
- FINAL_LR_FRAC fine-tuning (0.15, 0.25)
- Adam beta2 tuning
- Different MLP expansion ratio
- Grad accum schedule changes

## Full Experiment History

| # | Experiment | val_bpb | Status |
|---|-----------|---------|--------|
| 0 | Baseline (batch=16) | 1.191909 | keep |
| 0b | Baseline (batch=32) | 1.192676 | keep |
| 1 | 5% LR warmup | 1.244263 | discard |
| 2a | Depth 12 | crash | crash |
| 2b | Depth 10 | crash | crash |
| 2c | Depth 10, batch=16 | 1.373499 | discard |
| 3 | Matrix LR 0.06, Emb 0.9 | 1.181332 | keep |
| 4 | Matrix LR 0.08, Emb 1.2 | 1.178592 | keep |
| 5 | Matrix LR 0.12, Emb 1.8 | 1.183606 | discard |
| 6 | Warmdown 0.3 | 1.177074 | keep |
| 7 | Warmdown 0.15 | 1.180232 | discard |
| 8 | FINAL_LR_FRAC 0.1 | 1.174359 | keep |
| 9 | FINAL_LR_FRAC 0.2 | 1.174092 | keep |
| 10 | FINAL_LR_FRAC 0.3 | 1.174884 | discard |
| 11 | Weight decay 0.1 | 1.175010 | discard |
| 12 | Unembed LR 0.008 | 1.170299 | keep |
| 13 | Unembed LR 0.016 | 1.176043 | discard |
| 14 | Softcap 30 | 1.177892 | discard |
| 15 | Scalar LR 1.0 | 1.169471 | keep |
| 16 | Beta1 0.85 | 1.169895 | discard |
| 17 | **Depth 6** | **1.157848** | **keep** |
| 18 | Depth 4 | 1.184572 | discard |
| 19 | Batch 64 at depth 6 | 1.184304 | discard |
| 20 | Total batch 2**18 | 1.175643 | discard |
| 21 | SwiGLU | 1.159808 | discard |
| 22 | Window SSLL | 1.159303 | discard |
| 23 | Matrix LR 0.10 | 1.157981 | discard |
| 24 | Emb LR 1.5 | 1.159335 | discard |
| 25 | **Depth 5** | **1.157145** | **keep** |
| 26 | Depth 7 | 1.215677 | discard |
| 27 | Aspect 80 | 1.178817 | discard |
| 28 | Aspect 48 | 1.166972 | discard |
| 29 | HEAD_DIM 64 | 1.172555 | discard |
| 30 | Warmdown 0.2 | 1.159932 | discard |
| 31 | Window all-long | 1.160776 | discard |
| 32 | **Window all-short** | **1.154745** | **keep** |
| 33 | Matrix LR 0.12 retry | 1.158403 | discard |
| 34 | Weight decay 0.3 | 1.157864 | discard |
| 35 | **Muon warmup 100 steps** | **1.152740** | **keep** |
| 36 | Muon warmup 50 steps | 1.155855 | discard |
| 37 | **Softcap 10** | **1.151844** | **keep** |
| 38 | **Softcap 8** | **1.150743** | **keep** |
| 39 | Softcap 6 | 1.165857 | discard |
| 40 | x0_lambdas 0.2 | 1.152022 | discard |
| 41 | Muon momentum start 0.90 | 1.150916 | discard |
| 42 | **Cosine warmdown** | **1.150405** | **keep** |
