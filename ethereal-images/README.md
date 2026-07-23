# ethereal-images

**Official logic/service images and benchmark circuits** for the Ethereal
Logic Platform. A logic image (`.eth`) is
`tar(fabric config frames + 5-piece manifest + Ed25519 signature)` — the
"FPGA equivalent of a container image", portable across any Ethereal device
whose fabric is a superset of the image's declared region. This repo holds the
Phase-0/1 reference circuits used to validate the fabric end-to-end
(**AES-128**, **FIR16**, **PWM**, …) plus their bit-true golden vectors.

> **Status: scaffolding — no implementation yet (Phase 0 task `E0-INF1`).**
> Reference images are produced once `E0-MAP1..5` + `ethimg` exist. See
> `docs/ethereal-tasks.yaml`.

**License:** **MIT** for the packaging/tooling side of this repository
(image manifests, build scripts, metadata). The corresponding RTL *source*
for these reference circuits lives in
[`ethereal-fabric`](../ethereal-fabric)/[`ethereal-shell`](../ethereal-shell)
and is licensed **CERN-OHL-S-2.0**. See [LICENSE](LICENSE) and the root
[LICENSES.md](../LICENSES.md).

Part of the **Ethereal Logic Platform** monorepo
([root](../AGENTS.md)). For the design, see
[docs/ARCHITECTURE-OVERVIEW.md](../docs/ARCHITECTURE-OVERVIEW.md) and the
[ethereal-plan/](../ethereal-plan/) plan library.

## Structure (planned)

```
ethereal-images/
├── benchmarks/        # AES-128, FIR16, PWM, ... reference circuits + golden vectors
├── reference/         # official signed .eth images per release
└── ci/                # image build + bit-true compare harness
```
