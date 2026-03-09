# Agent 7 Facts (Big Batch Explorer)

## Best Config (batch=64, TOTAL_BATCH_SIZE=2**19)
- depth=8, AR=96, MLP2x, RoPE200K, init0.68, mlr=0.12, emb_lr=0.9, unemb=0.006, wd=0.2
- val_bpb = 1.0751, 289 steps, 27.0GB VRAM, 75.5M params

## Key Findings
- MLP2x optimal at batch=64 (not 3x like batch=32 agents). MLP1.5x=1.099, 2x=1.075, 2.25x=1.082, 2.5x=1.078, 3x=1.091
- mlr=0.12 optimal at batch=64 (0.10=1.095, 0.12=1.075, 0.14=1.113). Higher than batch=32 optimal (0.04-0.08)
- wd=0.2 >> wd=0.05 >> wd=0.3 at depth=8 AR=96
- warmdown=0.5 best (0.4 and 0.6 both worse)
- emb_lr=0.9 + unemb=0.006 helps vs defaults (0.6/0.004)
- depth=8 AR=96 > depth=6 AR=128 > depth=10 AR=64 > depth=10 AR=76
- depth=11,12: OOM at batch=64 regardless of MLP ratio
- RoPE 200K helps with MLP 2.5x but HURTS at MLP 4x at batch=64

## Architecture Map
| config | val_bpb | steps | VRAM |
|--------|---------|-------|------|
| d8 AR=96 MLP2x | 1.0751 | 289 | 27GB |
| d8 AR=96 MLP2.5x | 1.0785 | 266 | 28.6GB |
| d6 AR=128 MLP2x | 1.0816 | 302 | 20.9GB |
| d8 AR=96 MLP3x | 1.0907 | 227 | 30.2GB |
| d10 AR=64 MLP2.5x | 1.0946 | 256 | 29.6GB |
| d10 AR=76 MLP3x | 1.0960 | 207 | 37.2GB |

## Global Best (other agents, batch=32)
- agent2: 1.0482 at 2**17 batch, depth=8 AR=96 MLP3x mlr=0.04
- agent4: 1.0553 at 2**17 batch
