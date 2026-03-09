# Hunches

- Depth 10 might be sweet spot (more layers = more capacity within time budget)
- Higher aspect ratio (e.g., 96) could help if depth is kept moderate
- Weight decay 0.2 might be too high for smaller models
- WARMUP_RATIO=0.0 seems aggressive - small warmup might help stability
- MLP expansion ratio of 4x is standard but 3x or 5x worth testing
