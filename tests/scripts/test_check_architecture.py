"""The architecture check must fail on each thing it exists to catch."""

import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "check-architecture.py"


def run(root: Path, part: str, source: str) -> subprocess.CompletedProcess[str]:
    (root / part).mkdir()
    (root / part / "module.py").write_text(source, encoding="utf-8")
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(root)],
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.mark.parametrize(
    ("part", "source"),
    [
        ("core", "from dataclasses import dataclass\nFEE = 30 * 5 // 10_000\n"),
        ("core", "from core import limits\n"),
        ("core", "from . import limits\n"),
        ("api", "import json\nfrom http.server import BaseHTTPRequestHandler\n"),
        ("api", "from core import fee\nimport api.handler\n"),
    ],
)
def test_accepts(tmp_path: Path, part: str, source: str) -> None:
    result = run(tmp_path, part, source)
    assert result.returncode == 0, result.stdout


@pytest.mark.parametrize(
    ("part", "source", "message"),
    [
        ("core", "import os\n", "may not import 'os'"),
        ("core", "from math import ceil\n", "may not import 'math'"),
        ("core", "import api\n", "may not import 'api'"),
        ("core", "RATE = 0.003\n", "floating-point literal"),
        ("core", "def fee(a):\n    return a * 30 / 10_000\n", "'/' division"),
        ("core", "def fee(a):\n    a /= 2\n    return a\n", "'/' division"),
        ("core", "def fee(a):\n    return float(a)\n", "'float' is not allowed"),
        ("core", "def fee(a):\n    return round(a)\n", "'round' is not allowed"),
        ("core", "def fee(a):\n    print(a)\n", "'print' is not allowed"),
        ("api", "import requests\n", "may not import 'requests'"),
        ("api", "from flask import Flask\n", "may not import 'flask'"),
    ],
)
def test_refuses(tmp_path: Path, part: str, source: str, message: str) -> None:
    result = run(tmp_path, part, source)
    assert result.returncode == 1
    assert message in result.stdout


def test_passes_when_there_is_no_code(tmp_path: Path) -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(tmp_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0
