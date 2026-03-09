# Extending Multi-Agent Optimization Beyond GPT-2 Training

## Core Pattern

The autoresearch loop is domain-agnostic:

```
while True:
    read(results.tsv)        # what's been tried
    hypothesize()            # pick a change
    edit(config)             # apply it
    run(harness)             # measure
    record(result)           # append to results.tsv
```

Any task with **editable parameters** and a **scalar objective** can slot in. But the devil is in the gotchas.

---

## The Gotchas (Things That Must Be Solved Per Domain)

### 1. Server / Compute
- GPT-2 training fits on 1 GPU in ~5 minutes. Most interesting domains don't.
- **Question:** How long can one experiment take before the agent loop becomes impractical?
- ~5 min = sweet spot (100+ experiments overnight)
- ~30 min = still viable (30-50 experiments overnight)
- ~2 hr = painful (maybe 10 experiments, need smarter search)
- ~8 hr+ = need surrogate models or cheaper proxies first
- Multi-agent helps less when experiments are slow — the value is in parallel search, which requires parallel compute

### 2. Dataset
- GPT-2 uses FineWeb (fixed, download once, done)
- Other domains: data prep can be the hardest part
- Drug discovery: need molecular databases, docking software, force fields
- Trading: need clean historical data with no survivorship bias
- SQL: need a representative production-like database with realistic data distributions
- **The agent can't solve data problems.** Data must be pre-staged.

### 3. Objective Function
- GPT-2 has val_bpb — clean, scalar, monotonic, fast to compute
- Real objectives are messier:
  - **Multi-objective:** latency vs throughput vs cost (need to reduce to scalar or Pareto front)
  - **Noisy:** trading backtest varies by date range, need statistical significance
  - **Expensive:** drug binding affinity requires simulation, not just a forward pass
  - **Delayed:** "did this prompt engineering change actually help users?" — can't measure in 5 min
  - **Deceptive:** benchmark gaming (overfitting to eval set without generalizing)
- **Rule of thumb:** If a human expert can't look at the number and instantly say "better" or "worse," the agent will struggle too

### 4. Model / Artifact Selection
- GPT-2 training: the "model" IS the thing being optimized
- In other domains, what exactly is the agent editing?
  - Compiler: flags and passes (discrete, combinatorial)
  - SQL: query structure (syntax-constrained, not just numbers)
  - Prompts: natural language (huge search space, hard to define "edit")
  - Infrastructure: YAML/Terraform configs (typed, constrained)
  - Molecules: SMILES strings or graph edits (domain knowledge required)
- **Key constraint:** The agent must be able to make small, reversible changes and measure the effect

### 5. Harness / Reproducibility
- GPT-2: `python train.py` → deterministic-ish loss curve
- Other domains need:
  - Deterministic seeds / controlled randomness
  - Isolated environments (one experiment can't corrupt the next)
  - Timeout/kill for runaway experiments
  - Resource cleanup (GPU memory, temp files, database connections)
  - **Baseline reproducibility** — if the baseline changes between runs, deltas are meaningless

---

## Candidate Domains (Ranked by Feasibility)

### Tier 1: Drop-in Ready (minimal adaptation)

**Compiler Flag Optimization**
- Edit: compiler flags (CFLAGS, passes, -O levels, LTO, PGO)
- Objective: benchmark score (SPEC, custom workload)
- Harness: `make clean && make CFLAGS="..." && ./benchmark`
- Experiment time: 1-10 min
- Gotchas: combinatorial explosion, flags interact non-linearly
- Why it works: same loop, same structure, fast iteration

**Prompt Engineering**
- Edit: system prompt, few-shot examples, formatting instructions
- Objective: eval accuracy on held-out test set
- Harness: `python eval.py --prompt prompt.txt`
- Experiment time: 1-5 min (API calls)
- Gotchas: noisy (LLM outputs vary), need large eval sets, cost of API calls
- Why it works: agents ARE the domain experts here — they understand prompts natively

**Infrastructure Config Tuning**
- Edit: Nginx/PostgreSQL/Redis config parameters
- Objective: requests/sec, p99 latency, throughput
- Harness: `apply_config && run_benchmark`
- Experiment time: 2-10 min
- Gotchas: need isolated test environment, parameters interact, some changes require restart
- Why it works: configs are text files, benchmarks are scriptable

### Tier 2: Feasible With Setup Work

**SQL Query Optimization**
- Edit: query structure, indexes, hints, materialized views
- Objective: query latency on representative workload
- Harness: `psql -f query.sql` + `EXPLAIN ANALYZE`
- Experiment time: seconds to minutes
- Gotchas: need production-representative data, optimizer hints are DB-specific, index creation can be slow
- Multi-agent angle: different agents own different query patterns

**ML Hyperparameter Search (non-LLM)**
- Edit: learning rate, architecture, regularization, data augmentation
- Objective: validation metric (accuracy, F1, AUC)
- Harness: `python train.py --config config.yaml && python eval.py`
- Experiment time: 5 min - 2 hr depending on model
- Gotchas: already well-served by Optuna/Ray Tune — but those don't have LLM reasoning about WHY things work
- Multi-agent angle: agents can read papers, reason about architecture choices, not just grid search

**Trading Strategy Parameters**
- Edit: indicator periods, thresholds, position sizing, stop-loss levels
- Objective: Sharpe ratio, max drawdown, total return on backtest
- Harness: `python backtest.py --config strategy.yaml`
- Experiment time: 1-5 min
- Gotchas: overfitting to historical data is the #1 risk, need walk-forward validation, survivorship bias, transaction costs
- **Critical:** Need out-of-sample holdout the agent never sees, or it WILL overfit

### Tier 3: Possible But Hard

**Drug Molecule Optimization**
- Edit: SMILES strings, functional group substitutions
- Objective: predicted binding affinity (docking score), ADMET properties
- Harness: AutoDock/Vina, RDKit, or ML surrogate
- Experiment time: 1 min (ML surrogate) to 1 hr (full docking)
- Gotchas: synthesizability constraints, multi-objective (affinity + toxicity + solubility), domain expertise needed for meaningful edits
- Why it's hard: search space is combinatorially vast, most edits produce invalid molecules

**Chip/FPGA Design**
- Edit: RTL parameters, pipeline stages, buffer sizes, placement hints
- Objective: area × delay, power, frequency after synthesis
- Harness: synthesis tool (Yosys, Vivado)
- Experiment time: 10 min - 2 hr
- Gotchas: synthesis tools are heavy, parameter interactions are extreme, need hardware expertise
- Why it's interesting: Google already does this with ML (AlphaChip)

---

## What Multi-Agent Adds (vs Single Agent)

The 46% hit rate vs 19% isn't from more experiments — it's from these collaboration patterns:

| Pattern | Mechanism | Example |
|---------|-----------|---------|
| **Shared failures** | Blackboard records what didn't work → others don't repeat | Agent 6 found short_window hurts at depth=10 → all agents avoided it |
| **Combinatorial discovery** | Different agents explore different axes, then combine | Agent 1 found RoPE 200K + Agent 0 found depth=10 → Agent 6 combined them |
| **Strategic oversight** | Supervisor agent identifies underexplored regions | Supervisor noticed no one tried weight_decay variations → directed agent |
| **Quality control** | Judge agent reviews for confounds before recording | Agent 3 flagged keep-but-confounded when GPU contention was suspected |
| **Debate filtering** | Two agents argue before committing to expensive experiment | Debate agents A/B challenged each other's hypotheses |

These patterns transfer directly to other domains. A SQL optimization blackboard would record "index on column X didn't help query Y" so other agents don't waste time.

---

## Minimal Template for a New Domain

```
domain/
├── config.yaml          # the thing agents edit (replaces train.py)
├── run.sh               # harness: apply config, run, output score
├── results.tsv          # append-only log (commit, score, status, description)
├── strategy.md          # what's been tried, what to try next
├── best/
│   └── config.yaml      # current best configuration
├── program-multi.md     # agent instructions (domain-specific)
└── blackboard.md        # shared collaboration space
```

The `program-multi.md` needs to specify:
1. What file to edit and what parameters exist
2. How to run the harness and read the score
3. What "better" means (lower latency? higher accuracy?)
4. Any constraints (memory limits, valid parameter ranges)
5. How to record results in results.tsv

Everything else (the agent loop, screen sessions, collaboration files) stays the same.

---

## Open Questions

1. **When does LLM reasoning beat random/Bayesian search?** Probably when the search space has structure the LLM can reason about (like "RoPE base frequency affects positional encoding resolution"). For pure numerical optimization with no semantic meaning, Optuna wins.

2. **How do you prevent overfitting?** The GPT-2 setup has a fixed val set. Trading backtests are notorious for overfitting. Need held-out test sets the agent never evaluates against.

3. **How do you handle multi-objective?** Scalarize (weighted sum)? Pareto front? Let the supervisor agent make tradeoff decisions?

4. **What's the right number of agents?** 8 was chosen to match GPUs. For non-GPU tasks, you could run 20-50 agents. But coordination overhead grows. Blackboard might get noisy.

5. **Can agents learn across runs?** Right now each run starts fresh. Could agents read previous run results as "prior knowledge" without it being leakage? (It's not leakage if you're honest about it.)

6. **What about safety?** Trading agents that find degenerate strategies. Drug agents that propose toxic molecules. Infra agents that find configs that pass benchmarks but fail in production. Need guardrails per domain.
