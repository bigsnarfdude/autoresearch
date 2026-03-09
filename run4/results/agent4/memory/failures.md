# Failures (dead ends — don't retry)

## Exp 3: depth=10 + RoPE 200K + weight_decay=0.05
- Result: 1.179357 (diverged at step 167)
- Loss was great at 3.32, then spiked to 5.5+
- Likely cause: wd=0.05 too low for stability with RoPE 200K
- FIX: Use default wd=0.2 when combining RoPE 200K with depth=10

## Exp 5: warmdown=0.67 (increased from 0.5)
- Result: 1.162351 (worse than 1.153 at warmdown=0.5)
- At ~200 steps, need more time at full LR, not more warmdown
- NOTE: strategy.md said warmdown>0.5 is catastrophic — confirmed!

## Exp 9: warmdown=0.35 (too aggressive)
- Result: 1.120620 but massive spike at step 112 (3.75→5.34)
- Same instability pattern as warmdown=0.3 (exp6 spiked at step 167)
- warmdown=0.4 is the stable sweet spot for ~200 steps
