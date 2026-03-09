# Agent 5 Facts

## My Best Config (round 11): val_bpb=1.097
- DEPTH=8, ASPECT_RATIO=96 (model_dim=768, n_head=6)
- MLP_RATIO=3.0, mlr=0.08, wd=0.2, warmup=0, warmdown=0.5
- RoPE base=200000, init_scale=0.68x, softcap=15
- 220 steps, 15.6GB, 84.9M params at TOTAL_BATCH_SIZE=2**19

## Results
| Round | Experiment | BPB | Steps | VRAM |
|-------|-----------|-----|-------|------|
| 1 | Baseline (depth=8, ar=64) | 1.1866 | 183 | 11.7GB |
| 7 | D8+ar96+mlr0.08+wd0.05+MLP4x | 1.1262 | 218 | 17.3GB |
| 11 | D8+ar96+MLP3x+wd0.2+warmup0 (BEST@2**19) | 1.0973 | 220 | 15.6GB |
| 16 | D8+ar128+MLP3x+wd0.2+2**18 | 1.0984 | ~350 | 20.8GB |
| 17 | D8+ar96+MLP3x+SwiGLU+wd0.2+2**18 | 1.1320 | 403 | 18.1GB |

## Key Learnings (confirmed)
- ar=96 (wider) >> depth=10 at 2**19 batch
- MLP3x + wd=0.2 + warmup=0 is the winning combo
- warmup=0.05 HURTS with wd=0.2 (1.141 vs 1.097)
- warmdown=0.4 hurts at depth=8. Use 0.5
- softcap=30 hurts. Use 15
- mlr=0.08 sweet spot (0.04 too low, 0.10 too high)
- AR=128 too wide — model too large, fewer steps (1.098)
- SwiGLU + MLP3x too many params (99M vs 85M), much worse (1.132 vs 1.075)
- 2**18 batch is now unlocked — should use it

## Cross-Agent Intel
- Agent2: Global best 1.075 (depth=8 AR=96 MLP3x 2**18 wd=0.2)
- Agent3: 1.077 with emb_lr=0.9 on same config
- Agent4: 1.076 confirmed
- Agent6: SwiGLU helps at 2**19 but NOT with MLP3x at 2**18
