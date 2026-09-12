# 报告：E0-INF2 — CI 首次真实运行失败定位与修复（`sim` 镜像构建）

> 日期：2026-09-12 · 执行者：agent · 任务：`E0-INF2`（CI 骨架）
> 触发：仓库转为 public 后维护者首次 push（`69ba9c3`），`Lint and Test` 工作流第一次真实运行
> 远程事实来源：GitHub REST API（`https://api.github.com/repos/BaiTian6641/Astral_Platform`）
> 本机环境：**无 docker**（因此 `docker build` 与容器内 `make lint/test` 无法本地执行）；有 OSS-CAD suite（`~/oss-cad-suite`，verilator 5.051）+ RISC-V 工具链（`~/tools/riscv/usr/bin`）

---

## 1. 现象（API 实测，非推测）

Run **`34696652313`**（workflow `Lint and Test`，`head_sha 69ba9c3`，branch `main`，event `push`，`conclusion: failure`）：

| Job | 结果 |
|---|---|
| `Python tools lint (ruff + mypy) — non-blocking bootstrap` | **success**（6/6 步绿） |
| `Verilator lint + cocotb regression (in sim Docker)` | **failure** |
| workflow `Docs` | success |

失败的 `sim` job 步级时间戳（UTC）：

| # | Step | 结果 | 开始 → 结束 |
|---|---|---|---|
| 1 | Set up job | success | 13:31:17 → 13:31:18 |
| 2 | Checkout | success | 13:31:18 → 13:31:19 |
| 3 | Check sim Docker prerequisites | success | 13:31:19 → 13:31:19 |
| 4 | **Build sim Docker image** | **failure** | **13:31:19 → 13:32:12（53 s）** |
| 5 | Verilator lint (make lint) | skipped | — |
| 6 | cocotb regression (make test) | skipped | — |

* 53 秒这一数字是关键证据：整个 job 只活了 60 s。该镜像要**源码编译** Verilator + Yosys + VPR（Dockerfile 自述冷构建 45–90 min），因此
  - 排除 job 超时（`timeout-minutes: 30` 根本没到）；
  - 排除任何一个源码编译层——失败必然发生在最早的 apt 层。
* **无法取得 job 日志**：`/actions/jobs/103561174932/logs` 与 `/actions/runs/34696652313/logs` 均返回 **HTTP 403**（公共仓的 runner 日志同样需要 token）。故本次定位全部走「Dockerfile 静态核查 + 可达性实测 + 时间推断」，下文的 D1/D2 均为**确定性证据**（包索引 / tag 索引实测），不是猜测。

---

## 2. 根因（三个缺陷）

### D1（确定性；53 s 时机吻合）`python3.12-distutils` 在 deadsnakes jammy PPA 中不存在 → 第 1 层 apt 直接失败

* 证据：拉取 PPA 索引 `https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu/dists/jammy/main/binary-amd64/Packages.gz`（共 151 个包），`python3.12*` 只有
  `python3.12 / -dbg / -dev / -examples / -full / -gdbm / -gdbm-dbg / -lib2to3 / -tk / -tk-dbg / -venv`
  ——**没有** `python3.12-distutils`；索引里 `*distutils` 只剩 `python3.7-distutils / python3.8-distutils / python3.9-distutils`。
* 原因：上游 Python **3.12 已移除 distutils**（PEP 632），deadsnakes 只为 ≤3.11 提供该包。
* 后果：`apt-get install … python3.12-distutils` 以 `E: Unable to locate package python3.12-distutils`（exit 100）终止，发生在**第 1 个 RUN**；耗时与实测 53 s 吻合（apt update + 安装编译依赖 ≈40 s + 加 PPA/再 update ≈10 s + 立即报错）。

### D2（确定性；若不修必在 Yosys 层再次失败）`ARG YOSYS_TAG=yosys-0.59` 指向不存在的 tag

* 证据：`/git/ref/tags/yosys-0.59` → **HTTP 404**；`/git/ref/tags/v0.59` → **200**（release `v0.59` 发布于 2025-11-11）。
* 上游 tag 命名演进（全量 71 个 tag 实测）：`yosys-0.2.0` … `yosys-0.44` → 裸 `0.45` / `0.46` / `0.47` → `v0.48` … `v0.69`（最新 release `v0.69`，2026-09-09）。
* 后果：`git clone … --branch`/`git checkout yosys-0.59` 必然失败；它排在 Verilator 层之后，所以本次运行没机会暴露它，但修掉 D1 后就会撞上。

### D3（结构性；修掉 D1/D2 后必然命中）workflow 的 timeout 与「每次都是冷构建」不匹配

* `timeout-minutes: 30`，而 `docker/Dockerfile` 头部自述冷构建 **45–90 min**（三个源码构建）；GitHub hosted runner 为 4 vCPU（远少于作者笔记本）。
* 且原 workflow 用裸 `docker build`：**每次 push 都是冷构建**（hosted runner 无层缓存），即每次都要重编 Verilator + Yosys + VPR。

---

## 3. 已排除（检查过、未发现问题，避免后续误诊）

| 可疑项 | 核查结论 |
|---|---|
| `ADD`/`COPY` 了本地存在但 gitignore 的文件 | **不适用**：Dockerfile 完全没有 `COPY`/`ADD`（`docker/.dockerignore` 亦声明「image never COPY's repo sources」）。 |
| apt 包名在 jammy 失效 | 28 个包名（含新加的 `gawk`/`pkg-config`/`libtbb-dev`）在 `packages.ubuntu.com/jammy/` 全部 200。 |
| 基础镜像 / 下载 URL 失效 | `verilator` tag `v5.028` → 200；VTR tag `v8.0.0` → 200；`https://bootstrap.pypa.io/get-pip.py` → 200。 |
| pip/cocotb pin 与 Python 3.12 不兼容 | `cocotb 1.9.2` 的 classifier 明确含 `Python :: 3.12`（`requires_python >=3.6`）；`cocotb-test 0.2.6` 要求 `cocotb>=1.5`。 |
| Yosys 构建需要 clang/lld | `v0.59` Makefile 的 `config-gcc` 存在且走 gcc；`-fuse-ld=lld` 只在 `CONFIG=clang` 分支。 |
| VPR 因缺 TBB 而 cmake 报错 | `vpr/CMakeLists.txt` 是 `find_package(TBB)`（**非 REQUIRED**），缺 TBB 时 `VPR_EXECUTION_ENGINE=auto` 回落 serial，不会失败（仍补装 `libtbb-dev` 以走并行引擎）。 |
| 镜像缺 `make lint` / `make test` 所需工具 | `make test` = `make -C ethereal-fabric/tests/smoke test SIM=verilator`（cocotb 的 `Makefile.sim`，需 `cocotb-config` + verilator，二者均在镜像内），不依赖 iverilog；`make lint` 只需 verilator。契约自洽。 |
| workflow 引用路径未 tracked | `docker/Dockerfile`、`Makefile`、`ethereal-fabric/tests/smoke/**` 全部由 `git ls-files` 确认在库。 |

---

## 4. 修复内容

| 文件 | 改动 | 依据 |
|---|---|---|
| `docker/Dockerfile` | 删除 `python3.12-distutils`（第 1 层 python3.12 组） | D1 |
| `docker/Dockerfile` | `ARG YOSYS_TAG=yosys-0.59` → **`v0.59`**；section 头与文件头注释同步 | D2 |
| `docker/Dockerfile` | 新增 `gawk`、`pkg-config`（Yosys 上游 README 的 apt 依赖行）；新增 `libtbb-dev`（VPR `find_package(TBB)` → 并行 router） | 补齐构建依赖（非弱化） |
| `docker/Dockerfile` | 头部新增 **CI EVIDENCE** 注释块：记录 run/失败步/53 s/三个根因 | 可追溯 |
| `.github/workflows/lint-and-test.yml` | `timeout-minutes: 30` → **240**（远低于 GitHub hosted runner 的 6 h 上限；4 vCPU 的 runner 比作者笔记本慢，留足首次冷构建与缓存写入的余量） | D3（冷构建） |
| `.github/workflows/lint-and-test.yml` | Build step 改为 `docker/setup-buildx-action@v4` + `docker/build-push-action@v7`，`context: docker/`、`file: docker/Dockerfile`、`tags: ethereal-sim:latest`、`load: true`、`cache-from/to: type=gha` | D3（层缓存，只有首次付冷构建成本；`load` 保证后续 `docker run` 步骤不变） |
| `.github/workflows/lint-and-test.yml` | 新增「Free disk space」步骤（plain shell：删 `/usr/share/dotnet`、`/usr/local/lib/android`、`/opt/ghc`、`/opt/hostedtoolcache/CodeQL` + `df -h /`） | 三个源码构建 + 层缓存 + `--load` 副本在 hosted runner 上的磁盘余量（不引入第三方 action，遵守 dco.yml 同款供应链规则） |
| `.github/workflows/lint-and-test.yml` | 头部新增 HISTORY 注释 | 可追溯 |
| `docker/README.md` | Yosys 行 tag 更正为 `v0.59` + tag 命名说明；ASSUMPTION 块追加 2026-09-12 UPDATE；Build & run 段补一句 CI 走 buildx + GHA 缓存 | 文档与实现一致 |

**未改动（刻意）**：Verilator `v5.028`、Yosys `0.59`、VPR/VTR `v8.0.0`、cocotb `1.9.*`、Python 3.12 这些 pin（工具链契约）；根 `Makefile` 的 `lint` / `test` / `test-model` / `docker-build` / `docker-shell` 目标；任何 RTL / verif 内容。修的是「构建与 CI 编排」，没有任何 lint/test 门禁被削弱。

---

## 5. 验证矩阵（本机可做项全部执行）

| 项 | 方法 | 结果 |
|---|---|---|
| workflow YAML 可解析 | `python3 -c "import yaml; yaml.safe_load(...)"`（`lint-and-test.yml`） | ✅ OK（`timeout-minutes: 240`，步骤序列 = Checkout → prereq → free disk → buildx → build → lint → test） |
| 「本地有、CI 无」的被 gitignore 路径 | `git ls-files` 核对 Dockerfile/workflow 引用的每个路径 | ✅ 全部 tracked（Dockerfile 本身无 COPY） |
| 保留的 tag/URL 可达 | `curl`/urllib HEAD & API | ✅ verilator `v5.028` 200、yosys `v0.59` 200、VTR `v8.0.0` 200、get-pip 200、deadsnakes jammy 索引 200 |
| apt 包名存在 | `packages.ubuntu.com/jammy/<pkg>` × 28 | ✅ 全部 200 |
| Action 引用存在 | `/tree/v4`（setup-buildx）、`/tree/v7`（build-push） | ✅ 200；输入名（`context`/`file`/`tags`/`load`/`cache-from`/`cache-to`）与 action 源码/`action.yml` 一致 |
| Dockerfile 结构自检 | 自写解析：指令序列合法、**无注释落入 RUN 续行**（Docker 会先折叠续行，行内 `#` 会吃掉后续命令） | ✅ 通过 |
| 本地等价 `make lint` | `PATH=~/oss-cad-suite/bin:… make lint` | ✅ **PASS**（verilator 5.051 devel；`[lint] OK - all project RTL lint-clean.`，exit 0） |
| 本地等价 `make test-model` | 同上 | ✅ **2772 passed, 2 xfailed**, 1 warning, 96 s, exit 0 |

### 本机**无法**验证（诚实清单）

* 真实 `docker build`（本机无 docker）——包括「三个 pin 在 Ubuntu 22.04/GCC 11 上能否编译通过」这一 E0-INF3 遗留问题；Dockerfile 里 VTR `v8.0.0` 的 per-RUN fallback 注释**保留**。
* 容器内 `docker run … make lint / make test`（同上）。
* GitHub Actions 侧行为：GHA 层缓存是否命中、`--load`、磁盘步骤、以及**冷构建是否真能落在 240 min 内**（本机无法计时）。
* **Verilator 版本偏移**：镜像内是 5.028，本机 OSS-CAD 是 5.051 devel，`make lint` 的 waiver 集是按本地版本调过的；跨版本告警名/新增规则理论上可能不同。判据：新版本通常**新增**告警，本机在 5.051 上零告警 ⇒ 5.028（更老、告警更少）通过的可能性高，但**只能在 CI 里确认**（该 pin 属 E0-INF3 工具链契约，本次未改）。
* 首次运行的真实日志（403）。

---

## 6. 剩余步骤（维护者）

1. **下一次 push**：本环境**无 push 权限**（`origin` 为维护者个人账号），因此「首次远程变绿」只能由维护者的下一次 push 触发。
   预期：这次仍要付一次**冷构建**（45–90+ min，4 vCPU 可能更久）；该次运行会把层缓存写入 GHA cache，之后的 push 应恢复到分钟级。
2. 若这次仍失败：现在有两条定位路径——(a) 有 token 时读 job 日志；(b) 本地 `make docker-build` 可直接复现同一层（`docker build -f docker/Dockerfile -t ethereal-sim docker/`）。失败层现在最多是 Verilator/Yosys/VTR 三个源码构建之一（VTR `v8.0.0` 在 GCC 11 上最可疑，Dockerfile 已写明 fallback）。
3. 变绿后：把 `E0-INF2` 的 `status` 翻 `done`（本报告**不**代替该确认，故未改状态值）。
4. 可选（去风险）：把 `ethereal-sim` 发布到 GHCR，即可彻底消除冷构建（`docker/README.md` 已把它列为后续 infra 任务）。

---

## 7. 复现命令（附录）

```bash
# 1) 失败定位（无需 token）
curl -s https://api.github.com/repos/BaiTian6641/Astral_Platform/actions/runs/34696652313/jobs \
  | python3 -c 'import sys,json;[print(s["number"],s["name"],s["conclusion"],s["started_at"],s["completed_at"]) for j in json.load(sys.stdin)["jobs"] for s in j["steps"]]'
#    -> step 4 "Build sim Docker image" failure 13:31:19 -> 13:32:12 (53 s)
curl -sI https://api.github.com/repos/BaiTian6641/Astral_Platform/actions/jobs/103561174932/logs   # -> 403 (needs token)

# 2) D1：deadsnakes jammy 是否有 python3.12-distutils
python3 - <<'PY'
import urllib.request,gzip,re
t=gzip.decompress(urllib.request.urlopen("https://ppa.launchpadcontent.net/deadsnakes/ppa/ubuntu/dists/jammy/main/binary-amd64/Packages.gz").read()).decode()
n=sorted(set(re.findall(r"^Package: (\S+)$",t,re.M)))
print([x for x in n if "distutils" in x])          # ['python3.7-distutils','python3.8-distutils','python3.9-distutils']
print("python3.12-distutils" in n)                 # False
PY

# 3) D2：Yosys tag
curl -sI https://api.github.com/repos/YosysHQ/yosys/git/ref/tags/yosys-0.59   # 404
curl -sI https://api.github.com/repos/YosysHQ/yosys/git/ref/tags/v0.59        # 200

# 4) 本地等价验证
export PATH="$HOME/oss-cad-suite/bin:$HOME/tools/riscv/usr/bin:$PATH"
make lint && make test-model

# 5) 维护者机器（有 docker）：复现 / 验证镜像
make docker-build && make lint && make test
```
