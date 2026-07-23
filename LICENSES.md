# Licenses

This workspace is the **Ethereal Logic Platform + Astral OS** monorepo. It is
developed **monorepo-first, split-later**: the eight logical components live
as top-level directories, **each carrying its own `LICENSE`** so that a future
split into a GitHub organization (`ethereal-fpga`) is a mechanical, per-
directory operation with no re-licensing work. See `AGENTS.md` §7 ("Current
execution context") for the rationale.

## Per-directory license map

| Directory | License | SPDX identifier | One-line purpose |
|---|---|---|---|
| `ethereal-fabric/` | CERN Open Hardware Licence v2 — Strongly Reciprocal | `CERN-OHL-S-2.0` | RTL of the virtual reconfigurable overlay fabric (eLUT4, tiles, switch box, OCC, HAL). |
| `ethereal-shell/` | CERN Open Hardware Licence v2 — Strongly Reciprocal | `CERN-OHL-S-2.0` | RTL of the static Shell (EBI / Mailbox NoC, IO redirect, BMC SoC glue, Service Tile). |
| `ethereal-tools/` | MIT | `MIT` | Python toolchain: fabric-gen, mapper, bitgen, ethimg, ethctl. |
| `ethereal-runtime/` | MIT | `MIT` | ethereal-daemon + bmc-fw (C, NEORV32 → Zephyr in Phase 4). |
| `ethereal-spec/` | Creative Commons Attribution-ShareAlike 4.0 International | `CC-BY-SA-4.0` | Machine-readable + human specs (EBI, `.eth` image format, Board Manifest, EFP/ACP). |
| `ethereal-images/` | MIT *(RTL sources are CERN-OHL-S-2.0)* | `MIT` | Official logic/service images + benchmark circuits (AES-128, FIR16, PWM, …). |
| `astral-os/` | MIT | `MIT` | Astral embedded container runtime (Zephyr userspace + WAMR WASM; Type-N/W/F). |
| `docs/` | Creative Commons Attribution-ShareAlike 4.0 International | `CC-BY-SA-4.0` | Architecture docs, the `ethereal-plan/` library, and `reports/`. |

> **Note on `ethereal-images/`:** the MIT licence covers the packaging and
> tooling side (image manifests, build scripts, metadata, golden vectors).
> The RTL *source* of any reference circuit in this repo remains
> **CERN-OHL-S-2.0** and otherwise lives in `ethereal-fabric` /
> `ethereal-shell`. Cite the source's licence when redistributing RTL from
> here.

## License families in use

- **CERN-OHL-S-2.0** (hardware RTL — `ethereal-fabric`, `ethereal-shell`):
  strongly reciprocal open-hardware licence. Canonical text:
  <https://ohwr.org/cern_ohl_s_v2.txt> (verbatim copy in each repo's `LICENSE`,
  fetched from the SPDX license-list-data mirror).
- **MIT** (software — `ethereal-tools`, `ethereal-runtime`, `ethereal-images`,
  `astral-os`): permissive OSI-approved licence.
- **CC-BY-SA-4.0** (documentation & specs — `ethereal-spec`, `docs`):
  attribution + share-alike. Canonical legalcode:
  <https://creativecommons.org/licenses/by-sa/4.0/legalcode.txt> (verbatim
  copy in each repo's `LICENSE`).

The respective `LICENSE` files in each top-level directory are authoritative
for that directory. Always check the `SPDX-License-Identifier` header at the
top of individual source files (required by global rule G2).

## DCO — Developer Certificate of Origin

**All commits to this repository MUST be signed off** with a
`Signed-off-by: Your Name <email>` trailer (DCO). Use `git commit -s`.
This attests that you have the right to submit the work under the licence of
the files you are changing. See each repo's `CONTRIBUTING.md` and the root
`AGENTS.md`.

## License of new files

When adding a new file, apply the licence of the directory it lands in and add
the matching SPDX header:

- SystemVerilog / hardware RTL →
  `// SPDX-License-Identifier: CERN-OHL-S-2.0`
- Python / C / firmware →
  `# SPDX-License-Identifier: MIT`
- Markdown / YAML / JSON specs & docs →
  `SPDX-License-Identifier: CC-BY-SA-4.0`
