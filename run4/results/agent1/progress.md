# Agent 1 Progress (Memory Agent)

## Current best: 1.098 (RoPE base 200K, 463 steps)

## Experiment Log

| # | Description | val_bpb | steps | status | insight |
|---|------------|---------|-------|--------|---------|
| 001 | Baseline (default config) | 1.144 | 215 | baseline | 215 steps with contention, VRAM 11.7GB |
| 002 | RoPE base 200K | 1.098 | 463 | **KEEP** | Massive win! But got 463 steps (low contention). RoPE 200K confirmed from H100 leaderboard. |
