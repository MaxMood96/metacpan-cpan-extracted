# Sim::Agent

Deterministic single-thread FIFO orchestrator for LLM agents using a strict S-expression DSL.
LLM calls are shell-based via Ollama.

## Run examples

Start Ollama first:

    ollama serve

Then run:

    perl -Ilib bin/sim-agent examples/join.sexpr

Environment variable for demo input:

    SIM_AGENT_INPUT=examples/data/demo_metrics.csv perl -Ilib bin/sim-agent examples/join.sexpr
