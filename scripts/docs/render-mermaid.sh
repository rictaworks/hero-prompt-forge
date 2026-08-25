#!/usr/bin/env bash
# SPEC/ の Markdown に含まれる Mermaid の図を画像へ書き出します。
#
# 実行 : docker compose exec dev bash scripts/docs/render-mermaid.sh
#
# 出力先は SPEC/rendered/ です。GitHub 上では Markdown のまま表示されるため、
# 書き出しは資料として配布する場合に使います。
set -euo pipefail

cd "$(dirname "$0")/../.."

OUT_DIR="SPEC/rendered"
mkdir -p "$OUT_DIR"

shopt -s nullglob
FILES=(SPEC/*.md)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "SPEC/ に Markdown がありません。図を書き出す対象がありません。" >&2
  exit 1
fi

for f in "${FILES[@]}"; do
  name="$(basename "$f" .md)"
  echo "書き出し: $f"
  npx mmdc \
    --input "$f" \
    --output "${OUT_DIR}/${name}.md" \
    --configFile .mermaidrc.json \
    --puppeteerConfigFile puppeteer-config.json \
    --outputFormat svg
done

echo "書き出しました: ${OUT_DIR}"
