#!/usr/bin/env bash
# Build the static site from the markdown sources with pandoc.
# Usage: bash site/build.sh [outdir]   (default: _site)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="${1:-_site}"
mkdir -p "$out/figures"
for f in "$here"/*.md; do
  name="$(basename "$f" .md)"
  [ "$name" = "README" ] && continue
  pandoc "$f" --from markdown-smart --to html5 --standalone \
    --template "$here/template.html" \
    --lua-filter "$here/tables.lua" \
    -o "$out/$name.html"
done
cp "$here/style.css" "$out/"
cp "$here"/figures/*.png "$out/figures/"
touch "$out/.nojekyll"
echo "built site in $out"
