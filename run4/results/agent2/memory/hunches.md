# Hunches to Test

- TOTAL_BATCH_SIZE=2**18 could be huge — doubles steps from ~220 to ~440+
- HEAD_DIM=64 might help (more heads for same width)
- RoPE base 200K (Karpathy found this)
- Init scale 0.68x (Karpathy found optimal)
- short_window = seq_len // 8 might help
- Softcap changes (currently 15)
- scalar_lr tuning
