#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== [1/3] shared/ ==="
cd "$PROJECT_DIR/shared" && dart analyze lib/

echo ""
echo "=== [2/3] vcr_agent/ ==="
cd "$PROJECT_DIR/vcr_agent" && dart analyze

echo ""
echo "=== [3/3] lib/ (Flutter) ==="
cd "$PROJECT_DIR" && flutter analyze lib/

echo ""
echo "✅ All packages passed analysis."
