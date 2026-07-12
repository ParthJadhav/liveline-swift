#!/usr/bin/env bash
set -euo pipefail

VERSION="2.45.4"
SHA256="090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef"
PREFIX="${1:-${XCODEGEN_INSTALL_PREFIX:-$HOME/.local}}"
URL="https://github.com/yonaskolb/XcodeGen/releases/download/$VERSION/xcodegen.zip"

if [[ -x "$PREFIX/bin/xcodegen" ]] \
  && [[ "$("$PREFIX/bin/xcodegen" --version)" == "Version: $VERSION" ]]; then
  echo "XcodeGen $VERSION is already installed at $PREFIX/bin/xcodegen"
  exit 0
fi

temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
archive="$temporary_directory/xcodegen.zip"

curl --fail --location --silent --show-error "$URL" --output "$archive"
echo "$SHA256  $archive" | shasum --algorithm 256 --check --status
unzip -q "$archive" -d "$temporary_directory"

mkdir -p "$PREFIX/bin" "$PREFIX/share"
cp "$temporary_directory/xcodegen/bin/xcodegen" "$PREFIX/bin/xcodegen"
cp -R "$temporary_directory/xcodegen/share/xcodegen" "$PREFIX/share/xcodegen"
chmod +x "$PREFIX/bin/xcodegen"

echo "Installed XcodeGen $VERSION at $PREFIX/bin/xcodegen"
