#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the S4 Linux-boot images (E2-RV2 increment 7: OpenSBI -> Linux).

Everything the S4 boot needs, from sources that are pinned by hash:

1. **OpenSBI** ``v1.3`` (commit ``2552799a…``) built with ``FW_PIC=n``. v1.3 is
   the newest OpenSBI that builds with this workstation's only RISC-V toolchain:
   ``riscv64-unknown-elf-ld`` (binutils 2.42) has no ``-pie``/``-shared`` support,
   and OpenSBI >= v1.4 requires PIE unconditionally (``make`` stops at the probe).
   With ``FW_PIC=n`` v1.3 is a *stock* build, position-dependent at
   ``FW_TEXT_START`` = 0x8000_0000, which is exactly the S4 address plan.
2. **The kernel**: Alpine's ``linux-lts`` apk, whose ``boot/vmlinuz-lts`` is a
   gzip'd PE32+ EFI image that *is* a RISC-V flat ``Image`` (the PE header is
   overlaid on the image header's fields: ``text_offset`` at 0x08,
   ``image_size`` at 0x10, ``"RISCV"`` at 0x30, ``"RSC\\x05"`` at 0x38 — the same
   layout the kernel's own ``arch/riscv/include/asm/image.h`` describes). It is
   bootable exactly as the flat image ``fw_jump`` expects: the first instruction
   pair at the image start is the ``j _start_kernel`` jump (``_start`` is at the
   image base, ``_start_kernel`` at +0x10d8, both from ``System.map``).
3. **The initramfs**: a static riscv64 busybox (Ubuntu's ``busybox-static``) plus
   the checked-in ``s4/init``, packed as a gzip'd ``newc`` cpio.
4. **The device tree**: :file:`eth_rv_linux.dts` with its initramfs tokens filled
   in, compiled with the harness's ``dtc``.
5. **The S4 BootROM**: Spike's own reset vector (byte for byte, so the firmware
   portion of the boot is diffable against Spike commit by commit) with the stub
   step count and the device tree in the same 4 KiB page.

Pins are stated as URL + SHA-256 (and a git commit for OpenSBI) so the build is
reproducible and a moved upstream tag cannot change what runs. Downloads and the
checkout live under :data:`rv_platform.LINUX_WORK_DIR_REL` (gitignored
``build/``); the images land in ``generated/rv_difftest/s4/`` with a manifest the
runner reads. Nothing here is committed except the sources and this script.

Usage::

    python3 ethereal-shell/verif/eth_rv/build_linux_boot.py            # build all
    python3 ethereal-shell/verif/eth_rv/build_linux_boot.py --check    # verify only
    python3 ethereal-shell/verif/eth_rv/build_linux_boot.py --refresh  # re-download
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
import shutil
import struct
import subprocess
import sys
import tarfile
import urllib.request
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[2]
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import rv_platform  # noqa: E402  (lives beside this script)

# --- pins -------------------------------------------------------------------------

OPENSBI_REPO = "https://github.com/riscv-software-src/opensbi.git"
OPENSBI_TAG = "v1.3"
OPENSBI_COMMIT = "2552799a1df30a3dcd2321a8b75d61d06f5fb9fc"
"""``v1.3`` as tagged upstream; the build asserts the checkout is exactly this."""

KERNEL_APK_URL = (
    "https://dl-cdn.alpinelinux.org/alpine/edge/main/riscv64/linux-lts-6.18.48-r0.apk"
)
KERNEL_APK_SHA256 = "cc2f73ad5724f0e1646aa4153d0aec35c18c71cf5c5db5a40457751166f54f4c"

BUSYBOX_APK_URL = (
    "https://dl-cdn.alpinelinux.org/alpine/edge/main/riscv64/busybox-static-1.38.0-r4.apk"
)
BUSYBOX_APK_SHA256 = "7fed6d0939377e336e5f4c1e20fba6d6ecd8ad910f245e8af9362ed62c6fbd56"
"""Alpine's static busybox: the same distro as the kernel, and an apk (a gzip'd
tar) so the build needs no `dpkg-deb`/zstd support to unpack it."""

CROSS_COMPILE = "riscv64-unknown-elf-"
"""The bare-metal toolchain the whole eth_rv flow uses (``~/tools/riscv``)."""

ROM_BYTES = 4096
"""The S4 BootROM window: one 4 KiB page at ``rv_platform.ROM_BASE``."""

ROM_DTB_OFFSET = rv_platform.LINUX_ROM_DTB_ADDR - rv_platform.ROM_BASE
"""Where the device tree starts inside the ROM (32 = Spike's own reset-ROM slot)."""

FDT_MAGIC_BE = b"\xd0\x0d\xfe\xed"
"""The FDT header magic as it appears in the blob (big-endian)."""

IMAGE_MAGIC = b"RISCV"
IMAGE_MAGIC2 = b"RSC\x05"
"""``RISCV_IMAGE_MAGIC`` / ``RISCV_IMAGE_MAGIC2`` (arch/riscv/include/asm/image.h)."""


class BuildError(RuntimeError):
    """The build cannot proceed (missing tool, unreadable artefact, bad pin)."""


# --- small helpers ----------------------------------------------------------------


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def run(argv: list[str], *, cwd: Path | None = None) -> None:
    """Run a build step, failing loudly with its output."""
    proc = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        raise BuildError(f"command failed ({proc.returncode}): {' '.join(argv)}")
    if proc.stderr.strip():
        sys.stderr.write(proc.stderr)


def download(url: str, dest: Path, sha256: str, *, refresh: bool = False) -> Path:
    """Fetch ``url`` to ``dest`` once, verified against its pinned ``sha256``."""
    if dest.is_file() and not refresh and sha256_file(dest) == sha256:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    sys.stderr.write(f"[s4] downloading {url}\n")
    with urllib.request.urlopen(url, timeout=120) as response:  # noqa: S310 (pinned https/http)
        data = response.read()
    got = sha256_bytes(data)
    if got != sha256:
        raise BuildError(f"{url}: sha256 {got} != pinned {sha256}")
    dest.write_bytes(data)
    return dest


def find_toolchain(name: str) -> str:
    """Locate ``riscv64-unknown-elf-<name>`` on PATH or in the authoring toolchain."""
    found = shutil.which(f"{CROSS_COMPILE}{name}")
    if found:
        return found
    fallback = Path.home() / "tools" / "riscv" / "usr" / "bin" / f"{CROSS_COMPILE}{name}"
    if fallback.is_file():
        return str(fallback)
    raise BuildError(
        f"{CROSS_COMPILE}{name} not found: put ~/tools/riscv/usr/bin on PATH "
        "(the OpenSBI build needs the bare-metal toolchain)"
    )


def find_dtc() -> Path:
    """The harness's built ``dtc`` (or any ``dtc`` on PATH)."""
    for candidate in (REPO_ROOT / "generated" / "rv_difftest" / "dtc" / "dtc",):
        if candidate.is_file():
            return candidate
    found = shutil.which("dtc")
    if found:
        return Path(found)
    raise BuildError("dtc not found: build it under generated/rv_difftest/dtc or put dtc on PATH")



# --- stages -----------------------------------------------------------------------


def stage_opensbi(work: Path, out: Path, *, refresh: bool) -> dict[str, Any]:
    """Clone+checkout the pinned OpenSBI, build ``fw_jump`` with ``FW_PIC=n``."""
    checkout = work / "opensbi"
    if not checkout.is_dir() or refresh:
        if checkout.is_dir():
            shutil.rmtree(checkout)
        run(["git", "clone", "--depth", "1", "--branch", OPENSBI_TAG, OPENSBI_REPO, str(checkout)])
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=checkout, capture_output=True, text=True, check=True
    ).stdout.strip()
    if head != OPENSBI_COMMIT:
        raise BuildError(f"opensbi checkout is {head}, expected the pinned {OPENSBI_COMMIT}")
    run(
        [
            "make",
            "PLATFORM=generic",
            f"CROSS_COMPILE={CROSS_COMPILE}",
            "FW_PIC=n",
            f"-j{max(1, os.cpu_count() or 1)}",
        ],
        cwd=checkout,
    )
    firmware = checkout / "build" / "platform" / "generic" / "firmware"
    out.mkdir(parents=True, exist_ok=True)
    jump_bin = out / "fw_jump.bin"
    jump_elf = out / "fw_jump.elf"
    shutil.copyfile(firmware / "fw_jump.bin", jump_bin)
    shutil.copyfile(firmware / "fw_jump.elf", jump_elf)
    blob = jump_bin.read_bytes()
    if len(blob) < 0x1000:
        raise BuildError("fw_jump.bin is implausibly small — did the build really succeed?")
    return {
        "tag": OPENSBI_TAG,
        "commit": OPENSBI_COMMIT,
        "build": "PLATFORM=generic FW_PIC=n",
        "fw_jump_bin": jump_bin.name,
        "fw_jump_bin_bytes": len(blob),
        "fw_jump_bin_sha256": sha256_bytes(blob),
        "fw_jump_elf": jump_elf.name,
        "fw_jump_elf_entry": rv_platform.LINUX_FW_ENTRY,
    }


def stage_kernel(work: Path, out: Path, *, refresh: bool) -> dict[str, Any]:
    """Extract ``boot/vmlinuz-lts`` and carve the flat ``Image`` out of it."""
    apk = download(KERNEL_APK_URL, work / "linux-lts.apk", KERNEL_APK_SHA256, refresh=refresh)
    with tarfile.open(apk) as archive:
        member = archive.extractfile("boot/vmlinuz-lts")
        if member is None:
            raise BuildError(f"{apk}: no boot/vmlinuz-lts")
        compressed = member.read()
    image = gzip.decompress(compressed)
    _check_kernel_image(image)
    out.mkdir(parents=True, exist_ok=True)
    (out / "Image").write_bytes(image)
    return {
        "apk_url": KERNEL_APK_URL,
        "apk_sha256": KERNEL_APK_SHA256,
        "apk_bytes": apk.stat().st_size,
        "vmlinuz_bytes": len(compressed),
        "image_bytes": len(image),
        "image_sha256": sha256_bytes(image),
        "image_text_offset": _u64(image, 8),
        "image_size": _u64(image, 0x10),
        "image_version": struct.unpack_from("<I", image, 0x20)[0],
    }


def _u64(blob: bytes, offset: int) -> int:
    return int(struct.unpack_from("<Q", blob, offset)[0])


def _check_kernel_image(image: bytes) -> None:
    """The flat-image contract ``fw_jump`` relies on, checked field by field."""
    if len(image) < 0x40:
        raise BuildError("kernel image is too small to hold a header")
    text_offset = _u64(image, 8)
    image_size = _u64(image, 0x10)
    if text_offset != rv_platform.LINUX_KERNEL_TEXT_OFFSET:
        raise BuildError(
            f"kernel text_offset 0x{text_offset:x} != the SoC's FW_JUMP_OFFSET "
            f"0x{rv_platform.LINUX_KERNEL_TEXT_OFFSET:x}: fw_jump would jump to the wrong place"
        )
    if image[0x30:0x35] != IMAGE_MAGIC:
        raise BuildError(f"kernel image has no {IMAGE_MAGIC!r} magic at 0x30")
    if image[0x38:0x3C] != IMAGE_MAGIC2:
        raise BuildError(f"kernel image has no {IMAGE_MAGIC2!r} magic at 0x38")
    if not (len(image) <= image_size <= rv_platform.LINUX_RAM_WINDOW_BYTES - 0x20_0000):
        raise BuildError(
            f"kernel image_size 0x{image_size:x} does not fit the "
            f"{rv_platform.LINUX_RAM_WINDOW_BYTES / (1 << 20):.0f} MiB window"
        )


def stage_busybox(work: Path, *, refresh: bool) -> bytes:
    """The static riscv64 busybox binary out of the pinned Alpine apk."""
    apk = download(BUSYBOX_APK_URL, work / "busybox-static.apk", BUSYBOX_APK_SHA256,
                   refresh=refresh)
    with tarfile.open(apk) as archive:
        member = archive.extractfile("bin/busybox.static")
        if member is None:
            raise BuildError(f"{apk}: no bin/busybox.static")
        return member.read()


def build_initramfs(out: Path, busybox: bytes) -> dict[str, Any]:
    """Pack ``s4/init`` + busybox into a gzip'd ``newc`` cpio (deterministic)."""
    init_template = (HERE / "s4" / "init").read_text(encoding="utf-8")
    marker = rv_platform.LINUX_MILESTONE.decode("ascii")
    if "@MILESTONE@" not in init_template:
        raise BuildError(f"{HERE / 's4' / 'init'} lost its @MILESTONE@ token")
    init = init_template.replace("@MILESTONE@", marker).encode("utf-8")

    def entry(name: str, data: bytes, mode: int, ino: int, rdev: tuple[int, int] = (0, 0)) -> bytes:
        name_b = name.encode("ascii") + b"\0"
        header = b"070701" + b"".join(
            b"%08X" % value
            for value in (ino, mode, 0, 0, 1, 0, len(data), 0, 0, rdev[0], rdev[1], len(name_b), 0)
        )

        def pad4(blob: bytes) -> bytes:
            return blob + b"\0" * ((4 - len(blob) % 4) % 4)

        return pad4(header + name_b) + pad4(data)

    items: list[bytes] = []
    ino = 1

    def add(name: str, data: bytes, mode: int, rdev: tuple[int, int] = (0, 0)) -> None:
        nonlocal ino
        items.append(entry(name, data, mode, ino, rdev))
        ino += 1

    for directory in (".", "bin", "proc", "sys", "dev", "root"):
        add(directory, b"", 0o040755)
    add("dev/console", b"", 0o020600, (5, 1))
    add("dev/null", b"", 0o020666, (1, 3))
    add("bin/busybox", busybox, 0o100755)
    add("init", init, 0o100755)
    for applet in ("sh", "mount", "sleep", "cat"):
        add(f"bin/{applet}", b"busybox", 0o120777)
    raw = b"".join(items) + entry("TRAILER!!!", b"", 0, 0)
    raw += b"\0" * ((512 - len(raw) % 512) % 512)
    packed = gzip.compress(raw, 9, mtime=0)
    out.mkdir(parents=True, exist_ok=True)
    (out / "initramfs.cpio").write_bytes(raw)
    (out / "initramfs.cpio.gz").write_bytes(packed)
    return {
        "busybox_url": BUSYBOX_APK_URL,
        "busybox_sha256": BUSYBOX_APK_SHA256,
        "busybox_bytes": len(busybox),
        "cpio_bytes": len(raw),
        "initramfs_bytes": len(packed),
        "initramfs_sha256": sha256_bytes(packed),
        "milestone": marker,
    }


def build_dtb(out: Path, initramfs_bytes: int) -> dict[str, Any]:
    """Fill the DT template's initramfs tokens and compile it."""
    start = rv_platform.LINUX_INITRD_END - initramfs_bytes
    if start < rv_platform.LINUX_KERNEL_ADDR:
        raise BuildError(
            f"initramfs ({initramfs_bytes} bytes) does not fit above the kernel at "
            f"0x{rv_platform.LINUX_KERNEL_ADDR:x}"
        )
    template = (REPO_ROOT / rv_platform.LINUX_DTS_PATH_REL).read_text(encoding="utf-8")
    for token in ("@INITRD_START@", "@INITRD_END@"):
        if token not in template:
            raise BuildError(f"{rv_platform.LINUX_DTS_PATH_REL} lost its {token} token")
    text = template.replace(
        "@INITRD_START@", f"0x{start >> 32:x} 0x{start & 0xFFFFFFFF:x}"
    ).replace("@INITRD_END@", f"0x{rv_platform.LINUX_INITRD_END >> 32:x} "
                               f"0x{rv_platform.LINUX_INITRD_END & 0xFFFFFFFF:x}")
    dts = out / "eth_rv_linux.dts"
    dtb = out / "eth_rv_linux.dtb"
    dts.write_text(text, encoding="utf-8")
    run([str(find_dtc()), "-I", "dts", "-O", "dtb", "-o", str(dtb), str(dts)])
    blob = dtb.read_bytes()
    if not blob.startswith(FDT_MAGIC_BE):
        raise BuildError(f"{dtb}: does not start with the FDT magic")
    return {
        "dts": dts.name,
        "dtb": dtb.name,
        "dtb_bytes": len(blob),
        "dtb_sha256": sha256_bytes(blob),
        "initrd_start": start,
        "initrd_end": rv_platform.LINUX_INITRD_END,
    }


def build_rom(out: Path, dtb: bytes) -> dict[str, Any]:
    """Spike's reset vector + the S4 step count + the device tree, as a ROM image.

    The five instructions are Spike's own ``sim_t::set_rom()`` vector for a 64-bit
    hart; the encodings below are written from that source's expressions rather
    than copied, so a change in the assumption shows up here:

    * ``auipc t0, 0`` then ``addi a1, t0, 32`` -> a1 = ROM base + 32 = the tree;
    * ``csrr a0, mhartid`` -> the hart id;
    * ``ld t0, 24(t0)`` -> the 64-bit entry at word 6 (Spike's ``reset_vec[6:8]``);
    * ``jr t0`` -> hand over.

    The one deliberate difference from Spike's image is word 5, which carries this
    stub's instruction count: word 7 is Spike's step word *and* the entry's high
    half, so the S4 profile moves the count to the first word the stub never
    executes. The CLINT swallows it from there (``+rom_steps``/STUB_WORD), which is
    what keeps ``mtime`` on Spike's cadence.
    """
    reset_vec_size = 8
    vector = [
        0x297,  # auipc t0, 0
        0x28593 + (reset_vec_size * 4 << 20),  # addi a1, t0, 32
        0xF1402573,  # csrr a0, mhartid
        0x0182B283,  # ld t0, 24(t0)
        0x00028067,  # jr t0
    ]
    image = bytearray(bytes(ROM_BYTES))
    for index, word in enumerate(vector):
        struct.pack_into("<I", image, 4 * index, word)
    struct.pack_into("<I", image, 4 * rv_platform.LINUX_ROM_STEP_WORD,
                     rv_platform.LINUX_ROM_STUB_STEPS)
    struct.pack_into("<Q", image, 4 * rv_platform.LINUX_ROM_ENTRY_WORD,
                     rv_platform.LINUX_FW_ENTRY)
    if ROM_DTB_OFFSET + len(dtb) > ROM_BYTES:
        raise BuildError(
            f"the device tree ({len(dtb)} bytes) does not fit the {ROM_BYTES}-byte "
            f"BootROM after offset {ROM_DTB_OFFSET}"
        )
    image[ROM_DTB_OFFSET : ROM_DTB_OFFSET + len(dtb)] = dtb
    (out / "boot_rom_s4.bin").write_bytes(image)
    lines = [
        "# eth_rv boot rom hex v2 (s4 linux profile) -- do not edit",
        f"# base 0x{rv_platform.ROM_BASE:08x} bytes {ROM_BYTES} words {ROM_BYTES // 4} "
        f"entry_word {rv_platform.LINUX_ROM_ENTRY_WORD} "
        f"stub_word {rv_platform.LINUX_ROM_STEP_WORD} "
        f"stub_steps {rv_platform.LINUX_ROM_STUB_STEPS}",
        f"# a1 0x{rv_platform.LINUX_ROM_DTB_ADDR:08x} dtb_bytes {len(dtb)} "
        f"(Spike reset vector + device tree; generated by verif/eth_rv/build_linux_boot.py)",
    ]
    for index in range(ROM_BYTES // 4):
        word = int.from_bytes(image[4 * index : 4 * index + 4], "little")
        if word:
            lines.append(f"@{index:04x} {word:08x}")
    hex_text = "\n".join(lines) + "\n"
    (out / "boot_rom_s4.hex").write_text(hex_text, encoding="ascii")
    return {
        "boot_rom_hex": "boot_rom_s4.hex",
        "boot_rom_bin": "boot_rom_s4.bin",
        "boot_rom_hex_bytes": len(hex_text),
        "boot_rom_hex_sha256": sha256_bytes(hex_text.encode("ascii")),
        "rom_entry_word": rv_platform.LINUX_ROM_ENTRY_WORD,
        "rom_stub_word": rv_platform.LINUX_ROM_STEP_WORD,
        "rom_stub_steps": rv_platform.LINUX_ROM_STUB_STEPS,
        "rom_dtb_addr": rv_platform.LINUX_ROM_DTB_ADDR,
    }


# --- the build --------------------------------------------------------------------


def build(args: argparse.Namespace) -> dict[str, Any]:
    """Run every stage and return the manifest."""
    work = (REPO_ROOT / args.work_dir).resolve()
    out = (REPO_ROOT / args.out).resolve()
    work.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, Any] = {
        "profile": "s4-linux (E2-RV2 increment 7)",
        "ram_base": rv_platform.RAM_BASE,
        "ram_window_bytes": rv_platform.LINUX_RAM_WINDOW_BYTES,
        "fw_addr": rv_platform.LINUX_FW_ADDR,
        "fw_entry": rv_platform.LINUX_FW_ENTRY,
        "kernel_addr": rv_platform.LINUX_KERNEL_ADDR,
        "dtb_addr": rv_platform.LINUX_DTB_ADDR,
        "rom_dtb_addr": rv_platform.LINUX_ROM_DTB_ADDR,
        "isa": rv_platform.ISA_STRING,
        "timebase_frequency": rv_platform.TIMEBASE_FREQUENCY,
    }
    manifest["opensbi"] = stage_opensbi(work, out, refresh=args.refresh)
    manifest["kernel"] = stage_kernel(work, out, refresh=args.refresh)
    busybox = stage_busybox(work, refresh=args.refresh)
    manifest["initramfs"] = build_initramfs(out, busybox)
    manifest["dt"] = build_dtb(out, manifest["initramfs"]["initramfs_bytes"])
    manifest["rom"] = build_rom(out, (out / manifest["dt"]["dtb"]).read_bytes())
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                                       encoding="utf-8")
    return manifest


def check(out: Path) -> int:
    """Verify the built images are present and self-consistent."""
    manifest_path = out / "manifest.json"
    if not manifest_path.is_file():
        print(f"[s4] FAIL no manifest at {manifest_path}: run the build first")
        return 1
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    problems: list[str] = []
    for key, hash_key in (
        ("fw_jump.bin", "fw_jump_bin_sha256"),
        ("Image", "image_sha256"),
        ("initramfs.cpio.gz", "initramfs_sha256"),
        ("eth_rv_linux.dtb", "dtb_sha256"),
    ):
        path = out / key
        if not path.is_file():
            problems.append(f"{path} is missing")
            continue
        section = next(
            (value for value in manifest.values()
             if isinstance(value, dict) and hash_key in value), None
        )
        if section is None or sha256_file(path) != section[hash_key]:
            problems.append(f"{path}: sha256 does not match the manifest")
    dtb = out / manifest["dt"]["dtb"]
    if dtb.is_file() and not dtb.read_bytes().startswith(FDT_MAGIC_BE):
        problems.append(f"{dtb}: not a device tree blob")
    for problem in problems:
        print(f"[s4] FAIL {problem}")
    if problems:
        return 1
    print(
        f"[s4] OK {out}: kernel {manifest['kernel']['image_bytes']} B, "
        f"initramfs {manifest['initramfs']['initramfs_bytes']} B, "
        f"dtb {manifest['dt']['dtb_bytes']} B, "
        f"initrd [0x{manifest['dt']['initrd_start']:x}, 0x{manifest['dt']['initrd_end']:x})"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--work-dir", type=Path, default=rv_platform.LINUX_WORK_DIR_REL,
                        help=f"checkout/downloads (default: {rv_platform.LINUX_WORK_DIR_REL})")
    parser.add_argument("--out", type=Path, default=rv_platform.LINUX_BUILD_DIR_REL,
                        help=f"where the images are written (default: {rv_platform.LINUX_BUILD_DIR_REL})")
    parser.add_argument("--refresh", action="store_true", help="re-download and re-clone")
    parser.add_argument("--check", action="store_true", help="verify the built images and exit")
    args = parser.parse_args(argv)
    if args.check:
        return check((REPO_ROOT / args.out).resolve())
    try:
        manifest = build(args)
    except BuildError as exc:
        sys.stderr.write(f"[s4] error: {exc}\n")
        return 2
    kernel = manifest["kernel"]
    print(
        f"[s4] built into {REPO_ROOT / args.out}\n"
        f"[s4]   opensbi {manifest['opensbi']['tag']} ({manifest['opensbi']['commit'][:12]}) "
        f"fw_jump.bin {manifest['opensbi']['fw_jump_bin_bytes']} B\n"
        f"[s4]   kernel Image {kernel['image_bytes']} B "
        f"(text_offset 0x{kernel['image_text_offset']:x}, image_size 0x{kernel['image_size']:x})\n"
        f"[s4]   initramfs {manifest['initramfs']['initramfs_bytes']} B at "
        f"0x{manifest['dt']['initrd_start']:x}..0x{manifest['dt']['initrd_end']:x}\n"
        f"[s4]   dtb {manifest['dt']['dtb_bytes']} B, S4 boot rom "
        f"{manifest['rom']['boot_rom_hex']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
