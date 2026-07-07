#!/usr/bin/env bash
# Download Microsoft Visual C++ 2015-2022 redistributables for bundling
# inside D4Mac.app. These are the same files Microsoft ships at aka.ms; they
# are redistributable under MS's redist EULA. We fetch on-demand instead of
# committing 40 MB of binaries to git.
set -euo pipefail

cd "$(dirname "$0")"

declare -a urls=(
  "https://aka.ms/vs/17/release/vc_redist.x86.exe"
  "https://aka.ms/vs/17/release/vc_redist.x64.exe"
)

for url in "${urls[@]}"; do
  name="$(basename "$url")"
  if [ -f "$name" ]; then
    echo "have: $name ($(stat -f %z "$name") bytes)"
    continue
  fi
  echo "fetching ${name}..."
  curl -L -o "$name" "$url"
done

echo
echo "✓ prereqs ready in $(pwd)"
ls -la *.exe
