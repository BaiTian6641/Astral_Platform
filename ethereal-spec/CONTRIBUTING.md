# Contributing

Thanks for your interest in contributing! Before you start, please read the
**root [AGENTS.md](../AGENTS.md)** and
**[ethereal-plan/README.md](../ethereal-plan/README.md)** — they define the
project identity, the locked decisions (ADRs), and the mandatory engineering
rules **G1–G6** (lint-clean, standard module headers with `Plan-Ref:`,
acceptance reports in `docs/reports/`, Mermaid diagrams, and
**stop-and-ask on any uncertainty**).

Quick rules:

- **DCO required.** Every commit MUST include a
  `Signed-off-by: Your Name <email>` line (Developer Certificate of Origin).
  Use `git commit -s`.
- **Spec-first.** Change the spec in `ethereal-spec` (and bump the version)
  *before* changing any implementation.
- **Reports.** Non-trivial work needs a Markdown acceptance report in
  `docs/reports/` (rules G3/G4/G5).
- Pick an open task from `docs/ethereal-tasks.yaml` and discuss it in an issue
  before starting large work.

The licence of your contributions follows this repository's
[LICENSE](LICENSE). By contributing you agree to the Contributor Covenant
[Code of Conduct](CODE_OF_CONDUCT.md).
