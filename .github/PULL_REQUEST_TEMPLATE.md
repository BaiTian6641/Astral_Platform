<!--
Thanks for your contribution! Please review AGENTS.md and ethereal-plan/README.md
(rules G1–G6, locked ADRs) before submitting. Fill in the task ID from
docs/ethereal-tasks.yaml if this work maps to a planned task.
-->

## Summary

<!-- What does this change do, and why? Reference the task ID(s), e.g. E0-FAB1. -->

Task ID(s): <!-- e.g. E0-FAB1, or "n/a" -->

## Type of change

- [ ] RTL / hardware (`ethereal-fabric`, `ethereal-shell`)
- [ ] Toolchain / software (`ethereal-tools`, `ethereal-runtime`, `astral-os`)
- [ ] Spec / docs (`ethereal-spec`, `docs`)
- [ ] CI / infrastructure
- [ ] Other

## Checklist

- [ ] Passes `make lint` (e.g. `verilator --lint-only -Wall` for RTL, `ruff` +
      `mypy --strict` for Python, `-Wall -Wextra -Werror` for C). Zero new
      warnings unless a documented exemption (G1).
- [ ] Passes `make test` (cocotb / pytest / bit-true compare as applicable).
- [ ] Adds or updates an acceptance report in `docs/reports/`
      (`report-<taskId>-YYYYMMDD.md`) with the "this phase / next phase"
      sections and a Mermaid diagram where relevant (G3/G4/G5).
- [ ] Each commit has a `Signed-off-by: Your Name <email>` trailer (DCO).
- [ ] **No new vendor IP / primitives instantiated in own RTL** (ADR-017
      Inference-First); vendor specifics confined to `hal/<vendor>/glue/`
      with a Verilator stub.
- [ ] No change violates a locked ADR (see `AGENTS.md` §4).
- [ ] License headers present with the correct SPDX identifier for the
      directory's license (G2; see `LICENSES.md`).

## Notes for reviewers

<!-- Anything reviewers should pay attention to, ASSUMPTIONs made, or
     open questions raised (G6). -->
