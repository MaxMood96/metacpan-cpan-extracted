# Sim-AgentSoar

SOAR-inspired explicit search controller with deterministic invariants and a pluggable LLM worker.

## Install

```bash
perl Makefile.PL
make
make test
make install
```

## Modules

- `Sim::AgentSoar` (top-level)
- `Sim::AgentSoar::AgentSoar` (search controller)
- `Sim::AgentSoar::Engine` (deterministic environment)
- `Sim::AgentSoar::Node` (search state representation)
- `Sim::AgentSoar::Worker` (LLM-backed operator proposer via Ollama)
