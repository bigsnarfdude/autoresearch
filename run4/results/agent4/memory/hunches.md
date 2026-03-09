# Hunches (unconfirmed suspicions)

- HEAD_DIM=64 could help — more heads for same width = more attention capacity
- GQA (n_kv_head < n_head) could save params for more depth/width
- RoPE base 200K was found optimal on H100 leaderboard
- MLP ratio changes might help — 4x might not be optimal
- Softcap tuning (currently 15) — could be too aggressive or too mild
