# SPDX-License-Identifier: MIT
"""Shared fixtures for the ``eth_rv`` DiffTest harness tests.

The harness modules are plain top-level modules (same convention as the rest of
the repo's Python tools), so their directory is put on ``sys.path`` here instead
of requiring an installed package. Everything else in this directory tests that
those modules behave.
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
from types import ModuleType

import pytest

HARNESS_DIR = Path(__file__).resolve().parent.parent
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"
REPO_ROOT = HARNESS_DIR.parents[2]

if str(HARNESS_DIR) not in sys.path:
    sys.path.insert(0, str(HARNESS_DIR))

from rv_image import Image, load_hex_image
from rv_spike import SpikeError, find_spike, normalize_spike_log
from rv_trace import Commit


@pytest.fixture(scope="session")
def harness_dir() -> Path:
    """The ``ethereal-shell/verif/eth_rv`` directory under test."""
    return HARNESS_DIR


@pytest.fixture(scope="session")
def fixtures_dir() -> Path:
    """Directory holding the checked-in corpus fixtures."""
    return FIXTURES_DIR


@pytest.fixture(scope="session")
def cli_path(harness_dir: Path) -> Path:
    """The ``rv_difftest.py`` CLI entry point."""
    return harness_dir / "rv_difftest.py"


@pytest.fixture(scope="session")
def golden_log_text(fixtures_dir: Path) -> str:
    """Raw Spike ``--log-commits`` output for the model-targeted corpus program."""
    return (fixtures_dir / "cor_model.spike_log.txt").read_text(encoding="utf-8")


@pytest.fixture(scope="session")
def fixture_image(fixtures_dir: Path) -> Image:
    """The hex program image of the model-targeted corpus program."""
    return load_hex_image(fixtures_dir / "cor_model.hex")


@pytest.fixture(scope="session")
def golden_commits(golden_log_text: str, fixture_image: Image) -> list[Commit]:
    """The golden commit stream of the fixture log (boot ROM and spin loop trimmed)."""
    return normalize_spike_log(
        golden_log_text,
        source="fixture:cor_model.spike_log.txt",
        tohost=fixture_image.tohost,
        entry=fixture_image.entry,
    )


@pytest.fixture(scope="session")
def spike_binary() -> Path:
    """Path to the built Spike, or skip when this machine has none."""
    try:
        return find_spike()
    except SpikeError as exc:
        pytest.skip(f"spike not available: {exc}")


def _load_build_module() -> ModuleType:
    """Import ``corpus/build_corpus.py`` by path (it is a script, not a package)."""
    path = HARNESS_DIR / "corpus" / "build_corpus.py"
    spec = importlib.util.spec_from_file_location("corpus_build_corpus", path)
    if spec is None or spec.loader is None:  # pragma: no cover - import machinery failure
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


corpus_build = _load_build_module()


@pytest.fixture(scope="session")
def corpus_elfs(tmp_path_factory: pytest.TempPathFactory) -> dict[str, Path]:
    """Build the corpus programs once per session; skip when no toolchain is installed."""
    try:
        corpus_build.find_toolchain("gcc")
    except SystemExit as exc:
        pytest.skip(f"riscv toolchain not available: {exc}")
    out_dir = tmp_path_factory.mktemp("rv_difftest_corpus")
    return {source.stem: corpus_build.build_one(source, out_dir) for source in corpus_build.corpus_sources()}
