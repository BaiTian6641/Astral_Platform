# E3-REP1 验收报告 — OCI 兼容镜像仓库 v1（ethctl push/pull）

- **任务**: E3-REP1（OCI 兼容镜像仓库 v1）
- **日期**: 2026-09-12
- **状态**: **完成**（本地 OCI layout 全功能 + 最小 registry 传输；官方 registry 服务与真实 GHCR 互操作留后续）
- **Plan-Ref**: `ethereal-plan/subsystems/S09-镜像格式与仓库.md §2.1/§2.2/§2.3`、`S08-运行时daemon与ethctl.md`（`ethctl push/pull` 命令面）

---

## 1. 本阶段实现内容

| 文件 | 内容 |
|---|---|
| `ethereal-tools/tools/oci_registry.py`（新） | `LayoutStore`（`oci-layout` + `blobs/sha256/…` + `index.json`）与最小 `RegistryClient`（同一 Store Protocol 抽象）、描述符/引用原语、`push`/`pull`/`inspect`、`python -m oci_registry` CLI |
| `ethereal-tools/tools/test_oci_registry.py`（新） | 48 个测试（布局结构、签名/未签名往返、不可信密钥拒绝、tag 重指向、摘要引用拉取、6 类篡改、5 类畸形布局、假 registry HTTP 四态、CLI 与 `ethctl` 钩子） |
| `ethereal-tools/tools/ethctl.py` | 仅**增量** +51 行：`push`/`pull` 子命令 + 在任何 EMRI 传输之前早派发（S08/S09 的承诺命令面） |

### 映射（S09 §2 引用）

- **layer** = `.eth` tar，媒体类型 `application/vnd.ethereal.image.v1+tar`；
- **config** = `ethimg` 清单摘要（`…config.v1+json`，schema `ethereal.oci.config.v1`）：name/version/target/created、
  `manifest_digest`、成员摘要表、`signature.key_fingerprint`、`artifact{media_type,digest,size}`，同时设置 `artifactType`；
- **tag** = index 条目（`org.opencontainers.image.ref.name` + `io.ethereal.image.name`，支持多镜像布局与重指向）；
- **信任**：签名值与在 `.eth` 内一致，pull 时复用 `ethimg.verify`（默认 strict，`allow_unsigned` 显式放宽）——
  **不引入 OCI 专属信任通路**；
- **完整性顺序**：blob 摘要+尺寸 → config↔layer 匹配 → tar 成员摘要 + `manifest_digest` → config 身份/指纹匹配；
  目标文件经 `<dest>.part` + `os.replace` **仅在全部校验通过后**落地。

## 2. 验证（本人独立复跑）

- ✅ `.venv/bin/python -m pytest test_oci_registry.py test_ethimg.py test_ethctl.py -q` → **113 passed**（48 新 + 65 既有，无回归）。
- ✅ `ruff` 干净（3 个文件）。
- ✅ 篡改用例：layer blob / manifest blob / **全量重新摘要的 OCI 图** / 嫁接 config-artifact 对 / config 身份谎言 → 全部检出；
  篡改后**不留下部分文件**（`.part` 语义）。
- ✅ 假 registry（进程内 `ThreadingHTTPServer`）：往返、幂等重推、404 → `NotFoundError`、blob 篡改 → `DigestError`、
  拒连 → `TransportError`（无需真实 registry）。
- ✅ CLI 冒烟（agent 记录 + 本次复核）：push/inspect/pull 于 `/tmp` 布局，pull 与原文件 `cmp` 逐字节一致；
  `ethctl push/pull` 同样 exit 0 且逐字节一致。

## 3. 明确边界 / 假设（G6）

- ⚠️ `RegistryClient` 刻意最小化：真实 GHCR/Harbor 还需 token 握手、`POST→PATCH→PUT` 分块上传、
  `Docker-Content-Digest` 校验、cross-repo mount、referrers API、TLS/重试/限流、skopeo/oras 互操作（详见 notes）。
- ⚠️ **假设（写入 notes，S09 §7.1/§7.2/§7.3 仍开放）**：v1 每镜像**恰好一个** `.eth` layer；出现第二个 layer 直接报
  `LayoutError` 而非静默忽略。
- ⚠️ push 拒绝发布损坏镜像；**已签名镜像 push 需提供 `--pubkey`**（`ethimg.verify` 无密钥无法校验签名，已文档化并测试）。
- ⚠️ 未做：官方索引服务（S09 §3-P3#2）、registry 侧 `/v2` 实现、多目标 layer 扇出、ghcr.io 实网验证
  （无凭据/无 skopeo/oras/umoci）。

## 4. 下一阶段需要做的内容

- **E3-REP2（候选）** — 真实 registry 传输（token 流程 + 分块上传 + referrers）与 `skopeo`/`oras` 互操作验证。
- **E2-DOC1** — 把 §3 的 v1 假设（单 layer、push 需要 pubkey）写进 S09 的冻结文本。
- 队列后续：E2-DMA1（进行中）、E2-AXI2（进行中）、E2-RV1（RV-B，前置已就绪）。
