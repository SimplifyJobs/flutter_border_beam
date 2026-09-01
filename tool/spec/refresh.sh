#!/usr/bin/env bash
#
# Re-vendors the upstream border-beam spec into `test/fixtures/`.
#
# The React library ships a machine-readable `spec/beam-spec.json` generated
# from its `src/styles.ts`. `test/constants/spec_parity_test.dart` reads the
# vendored copy and asserts every table in `lib/src/constants/` against it, so
# the fixture is the parity test's ground truth and must be refreshed whenever
# upstream moves.
#
# Writes (idempotent — re-running on an unchanged upstream leaves the tree
# untouched):
#   test/fixtures/beam-spec.json   the spec, byte for byte as upstream has it
#   test/fixtures/UPSTREAM         commit=, version=, package_version=,
#                                  spec_version=, styles_sha256=
#
# `styles_sha256` hashes the upstream `src/styles.ts` the spec was generated
# from; `.github/workflows/upstream_drift.yaml` compares against it so a
# styles change that never reached the spec generator still raises the alarm.
#
# Usage:
#   tool/spec/refresh.sh            # fetch from main
#   tool/spec/refresh.sh <ref>      # fetch from a tag/branch/sha
#
# Needs `curl`, `jq`, and `shasum`. After running, re-read
# `lib/src/constants/upstream.dart` (its version strings are hand-maintained),
# then run:
#   flutter test test/constants/spec_parity_test.dart
set -euo pipefail

REPO="Jakubantalik/Libraries"
PKG="packages/border-beam"
REF="${1:-main}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixtures="$repo_root/test/fixtures"
mkdir -p "$fixtures"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Downloads $2 from the package at commit $1 into $work/$3, preserving the
# bytes exactly — command substitution would eat the trailing newline and
# change the styles.ts hash.
raw() {
  curl -fsSL "https://raw.githubusercontent.com/$REPO/$1/$PKG/$2" -o "$work/$3"
}

echo "Fetching $REPO@$REF …"

# Resolve the ref to a concrete commit so the fixture records exactly what was
# fetched, even when REF is a moving branch.
commit="$(curl -fsSL \
  -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/$REPO/commits/$REF" | jq -r .sha)"
if [ -z "$commit" ] || [ "$commit" = "null" ]; then
  echo "error: could not resolve $REPO@$REF to a commit" >&2
  exit 1
fi

raw "$commit" "spec/beam-spec.json" spec.json
raw "$commit" "src/styles.ts" styles.ts
raw "$commit" "package.json" package.json

jq empty < "$work/spec.json" # reject a truncated or non-JSON download

version="$(jq -r .sourceLibrary.version < "$work/spec.json")"
spec_version="$(jq -r .specVersion < "$work/spec.json")"
package_version="$(jq -r .version < "$work/package.json")"
styles_sha256="$(shasum -a 256 < "$work/styles.ts" | cut -d' ' -f1)"

cp "$work/spec.json" "$fixtures/beam-spec.json"

cat > "$fixtures/UPSTREAM" <<EOF
commit=$commit
version=$version
package_version=$package_version
spec_version=$spec_version
styles_sha256=$styles_sha256
EOF

echo "Vendored $PKG spec:"
sed 's/^/  /' "$fixtures/UPSTREAM"
echo
echo "Next: flutter test test/constants/spec_parity_test.dart"
