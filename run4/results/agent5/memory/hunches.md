# Agent 5 Hunches

- Depth 10 with aspect ratio ~51 might be good (more layers = more capacity per param)
- Higher warmup might stabilize training with deeper models
- Weight decay 0.2 seems high for small models, might try lower
- Softcap=15 on logits could be limiting - worth testing higher values
