# Agent 7 Hunches

- Depth 10+ might work better at batch=64 because bigger batch = more gradient signal per step
- Higher LR might be needed at batch=64 (linear scaling rule)
- Deeper models (10-12) that fail at batch=32 might work here due to more VRAM headroom
