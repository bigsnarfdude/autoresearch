# Hunches to Test

- **2**16 batch** — if halving keeps helping, this gives ~1740 steps. grad_accum drops to 1 (no accumulation). Risky but huge potential.
- **mlr tuning at 870 steps** — mlr=0.08 was tuned for ~200-400 steps. At 870 steps, might need higher or lower.
- **wd tuning at 870 steps** — wd=0.2 with linear decay might need adjustment for 870 steps.
- **warmdown at 870 steps** — 0.5 warmdown means 435 steps of cooldown. Could tune.
- **SwiGLU activation** (agent6 finding) — test at 2**17 batch
- **scalar_lr tuning** — completely untested at any config
- **depth=6 + AR=128** — extreme width, even more steps
