#!/usr/bin/env python3
"""Fails when the code breaks a guarantee of the specification that a machine can check.

core/  imports only the modules in CORE_IMPORTS, so it depends on nothing and
       does no input or output; it holds no float literal, no true division
       and none of the names in CORE_BANNED_NAMES, so it works in integers.
api/   imports only the standard library, core and itself.

Usage: check-architecture.py [root]    (root defaults to the current directory)
"""

import ast
import sys
from collections.abc import Iterator
from pathlib import Path

CORE_IMPORTS = {"__future__", "core", "dataclasses", "enum", "typing"}
CORE_BANNED_NAMES = {"float", "round", "open", "print", "input"}
API_IMPORTS = sys.stdlib_module_names | {"core", "api"}


def imported_modules(tree: ast.AST) -> Iterator[tuple[int, str]]:
    """Yields (line, top-level module) for every absolute import."""
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                yield node.lineno, alias.name.split(".")[0]
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            yield node.lineno, node.module.split(".")[0]


def check_file(path: Path, part: str) -> Iterator[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    allowed = CORE_IMPORTS if part == "core" else API_IMPORTS
    for line, module in imported_modules(tree):
        if module not in allowed:
            yield f"{path}:{line}: {part}/ may not import '{module}'"
    if part != "core":
        return
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, float | complex):
            yield f"{path}:{node.lineno}: floating-point literal in core/"
        elif isinstance(node, ast.BinOp | ast.AugAssign) and isinstance(
            node.op, ast.Div
        ):
            yield f"{path}:{node.lineno}: '/' division in core/; use integer arithmetic"
        elif isinstance(node, ast.Name) and node.id in CORE_BANNED_NAMES:
            yield f"{path}:{node.lineno}: '{node.id}' is not allowed in core/"


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    problems = [
        problem
        for part in ("core", "api")
        for path in sorted((root / part).rglob("*.py"))
        for problem in check_file(path, part)
    ]
    for problem in problems:
        print(problem)
    if problems:
        return 1
    print("Architecture: core/ and api/ keep the specification's guarantees.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
