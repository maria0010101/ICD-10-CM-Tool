#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
PYTHON=${PYTHON:-.venv313/bin/python}
"$PYTHON" -m pytest tools/data_builder/tests -q
(cd app && flutter analyze && flutter test)
