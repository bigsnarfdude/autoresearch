# Agent 7 Facts (Big Batch Explorer)

## Baseline
- depth=8, batch=64, default config: val_bpb=1.1415, 22.8GB VRAM, 229 steps, 120M tokens
- Compare: batch=32 agents get ~500 steps at depth=8 (same total tokens due to TOTAL_BATCH_SIZE)

## Key Constraints
- GPU 7: A100-SXM4-40GB, 40GB total
- batch=64 uses ~23GB at depth=8, leaving ~17GB headroom
- Can safely try depth 10, 12, maybe 14

## Experiments Run
1. Baseline depth=8 batch=64: 1.1415
