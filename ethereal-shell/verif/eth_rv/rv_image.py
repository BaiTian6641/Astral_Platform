# SPDX-License-Identifier: MIT
"""Program images for the ``eth_rv`` DiffTest harness (S15 §2.2).

An :class:`Image` is the flat-memory view of a program: its entry point, the
loaded segments, and the HTIF mailbox addresses (``tohost``/``fromhost``) that
terminate a run. Both producers understand the same images:

* the Python model DUT (:mod:`rv_model`) loads them to execute, and
* the spike golden generator (:mod:`rv_spike`) reads ``tohost`` to know which
  store ends the trace (Spike keeps committing the program's final spin loop
  for a few thousand instructions after the HTIF exit is armed).

Two formats are accepted: bare-metal ELF64 (the corpus) and a small
self-describing hex image (used by the harness's tracked fixtures so pytest runs
without the toolchain).
"""
from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path

ELF_MAGIC = b"\x7fELF"


class ImageError(RuntimeError):
    """The program image cannot be loaded (bad file, missing symbols)."""


@dataclass(frozen=True, slots=True)
class Image:
    """A loadable program image: flat segments + the two HTIF addresses."""

    name: str
    entry: int
    tohost: int
    segments: tuple[tuple[int, bytes], ...]
    """``(address, bytes)`` pairs written into memory before the first fetch."""
    fromhost: int = 0

    @property
    def size_bytes(self) -> int:
        """Total size of the loaded segments (diagnostics only)."""
        return sum(len(data) for _, data in self.segments)


def _check(condition: bool, message: str) -> None:
    if not condition:
        raise ImageError(message)


def load_elf_image(path: str | Path) -> Image:
    """Load PT_LOAD segments, entry and ``tohost`` from an ELF64 LE executable."""
    elf_path = Path(path)
    blob = elf_path.read_bytes()
    _check(blob[:4] == ELF_MAGIC, f"{elf_path}: not an ELF file")
    _check(len(blob) > 64 and blob[4] == 2 and blob[5] == 1, f"{elf_path}: need ELF64 little-endian")
    (entry,) = struct.unpack_from("<Q", blob, 24)
    phoff = struct.unpack_from("<Q", blob, 32)[0]
    shoff = struct.unpack_from("<Q", blob, 40)[0]
    phentsize, phnum = struct.unpack_from("<HH", blob, 54)
    shentsize, shnum = struct.unpack_from("<HH", blob, 58)
    segments: list[tuple[int, bytes]] = []
    for index in range(phnum):
        base = phoff + index * phentsize
        (p_type,) = struct.unpack_from("<I", blob, base)
        if p_type != 1:  # PT_LOAD
            continue
        p_offset, p_vaddr = struct.unpack_from("<QQ", blob, base + 8)
        (p_filesz,) = struct.unpack_from("<Q", blob, base + 32)
        segments.append((p_vaddr, blob[p_offset : p_offset + p_filesz]))
    symbols = _elf_symbols(blob, shoff, shentsize, shnum)
    _check("tohost" in symbols, f"{elf_path}: no `tohost` symbol — link with corpus/link.ld")
    return Image(
        name=elf_path.name,
        entry=entry,
        tohost=symbols["tohost"],
        fromhost=symbols.get("fromhost", 0),
        segments=tuple(segments),
    )


def _elf_symbols(blob: bytes, shoff: int, shentsize: int, shnum: int) -> dict[str, int]:
    """Symbol name -> value, from the ELF's SHT_SYMTAB section."""
    symbols: dict[str, int] = {}
    for index in range(shnum):
        base = shoff + index * shentsize
        (sh_type,) = struct.unpack_from("<I", blob, base + 4)
        if sh_type != 2:  # SHT_SYMTAB
            continue
        sh_offset, sh_size, sh_link = struct.unpack_from("<QQI", blob, base + 24)
        strtab_offset = struct.unpack_from("<Q", blob, shoff + sh_link * shentsize + 24)[0]
        for sym in range(sh_offset, sh_offset + sh_size, 24):
            (st_name,) = struct.unpack_from("<I", blob, sym)
            (st_value,) = struct.unpack_from("<Q", blob, sym + 8)
            end = blob.index(b"\0", strtab_offset + st_name)
            name = blob[strtab_offset + st_name : end].decode("utf-8", errors="replace")
            if name and name not in symbols:
                symbols[name] = st_value
    return symbols


def load_hex_image(path: str | Path) -> Image:
    """Load a self-describing hex image::

        # rv_difftest hex image v1
        # entry 0x80000000
        # tohost 0x80001000
        @80000000 00000297 00028517
        @80000008 00000013

    ``@<addr>`` words are little-endian; an even number of hex digits per word
    (4 = 2 bytes, 8 = 4 bytes). Checked into ``tests/fixtures`` so the harness's
    own tests exercise the example DUT without the toolchain or Spike.
    """
    hex_path = Path(path)
    entry: int | None = None
    tohost: int | None = None
    segments: dict[int, bytearray] = {}
    for lineno, raw in enumerate(hex_path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#"):
            fields = line.lstrip("#").split()
            if len(fields) == 2 and fields[0] in {"entry", "tohost"}:
                if fields[0] == "entry":
                    entry = int(fields[1], 16)
                else:
                    tohost = int(fields[1], 16)
            continue
        fields = line.split()
        if not fields[0].startswith("@"):
            raise ImageError(f"{hex_path}:{lineno}: expected `@<addr>` or a comment")
        addr = int(fields[0][1:], 16)
        cursor = addr
        for word in fields[1:]:
            size = len(word) // 2
            if len(word) % 2 or size not in (1, 2, 3, 4, 8):
                raise ImageError(f"{hex_path}:{lineno}: bad word {word!r}")
            try:
                value = int(word, 16)
            except ValueError:
                raise ImageError(f"{hex_path}:{lineno}: bad word {word!r}") from None
            data = value.to_bytes(size, "little")
            segment = segments.setdefault(addr, bytearray())
            offset = cursor - addr
            if offset + size > len(segment):
                segment.extend(bytes(offset + size - len(segment)))
            segment[offset : offset + size] = data
            cursor += size
    if entry is None or tohost is None:
        raise ImageError(f"{hex_path}: hex image must declare `# entry` and `# tohost`")
    return Image(
        name=hex_path.name,
        entry=entry,
        tohost=tohost,
        segments=tuple((addr, bytes(data)) for addr, data in sorted(segments.items())),
    )


def load_image(path: str | Path) -> Image:
    """Load an ELF or hex image (auto-detected by content)."""
    image_path = Path(path)
    _check(image_path.is_file(), f"image not found: {image_path}")
    with image_path.open("rb") as handle:
        magic = handle.read(4)
    if magic == ELF_MAGIC:
        return load_elf_image(image_path)
    return load_hex_image(image_path)
