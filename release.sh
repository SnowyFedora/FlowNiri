#!/usr/bin/env bash
# ============================================================
#  FlowNiri — release builder
#
#  Usage: ./release.sh [--version 1.1.0] [--notes "text"] [--dry-run]
#
#  * packs the whole repository (except .git and old zips) into
#    FlowNiri-<version>.zip with a top-level "FlowNiri/" folder,
#    the layout update.sh / rollback.sh expect
#  * commits the source tree, creates the tag v<version> and pushes it
#  * gh release create <tag> FlowNiri-<version>.zip --repo SnowyFedora/FlowNiri
#
#  Source tree : ~/FlowNiri   (override with FLOWNIRI_SRC)
#  Release repo: SnowyFedora/FlowNiri
# ============================================================
set -euo pipefail

SRC="${FLOWNIRI_SRC:-$HOME/FlowNiri}"
REL_REPO="SnowyFedora/FlowNiri"
BRANCH="main"

DRY_RUN=0
VERSION=""
NOTES=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift;;
        --version) VERSION="${2#v}"; shift 2;;
        --notes)   NOTES="$2"; shift 2;;
        -h|--help) sed -n '2,17p' "$0"; exit 0;;
        *) echo "Unknown option: $1" >&2; exit 2;;
    esac
done

[ -d "$SRC" ] || { echo "[ERROR] source tree not found: $SRC" >&2; exit 1; }
[ -f "$SRC/FlowNiri/manifest.txt" ] || { echo "[ERROR] $SRC/FlowNiri/manifest.txt is missing" >&2; exit 1; }

[ -n "$VERSION" ] || VERSION="$(head -1 "$SRC/FlowNiri/.version" | tr -d '[:space:]')"
[ -n "$VERSION" ] || { echo "[ERROR] version unknown (FlowNiri/.version is empty)" >&2; exit 1; }
TAG="v${VERSION#v}"
[ -n "$NOTES" ] || NOTES="FlowNiri $VERSION — themes, menus, AI monitor, updates and rollback."

OUT="$SRC/FlowNiri-$VERSION.zip"
rm -f "$OUT"

# ---- 1. build the archive (top-level folder "FlowNiri/") ------------------
python3 - "$SRC" "$OUT" <<'PY'
import os, sys, zipfile

src, out = sys.argv[1], sys.argv[2]
skip_dirs = {".git", "__pycache__", ".idea"}
skip_suffix = (".zip", ".pyc")

count = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in skip_dirs)
        for name in sorted(files):
            if name.endswith(skip_suffix):
                continue
            full = os.path.join(root, name)
            if os.path.islink(full) or not os.path.isfile(full):
                continue
            arc = "FlowNiri/" + os.path.relpath(full, src)
            z.write(full, arc)
            count += 1
print("zip: %s (%d files)" % (out, count))
PY

# ---- 2. verify the archive layout ---------------------------------------
python3 - "$OUT" <<'PY'
import sys, zipfile
names = set(zipfile.ZipFile(sys.argv[1]).namelist())
need = [
    "FlowNiri/FlowNiri/manifest.txt",
    "FlowNiri/FlowNiri/.version",
    "FlowNiri/niri/config.kdl",
    "FlowNiri/install.sh",
    "FlowNiri/README.md",
]
missing = [n for n in need if n not in names]
if missing:
    print("[ERROR] bad archive, missing: " + ", ".join(missing), file=sys.stderr)
    sys.exit(1)
if any(n == ".git" or n.startswith(".git/") for n in names):
    print("[ERROR] archive contains .git", file=sys.stderr)
    sys.exit(1)
print("archive OK: %d entries, root folder FlowNiri/" % len(names))
PY

echo "-> version $VERSION, tag $TAG"
echo "-> artifact: $OUT"

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] no commit, no tag, no push, no release created."
    exit 0
fi

# ---- 3. commit + tag + push the source tree ------------------------------
cd "$SRC"
git add -A
if git diff --cached --quiet; then
    echo "-> nothing to commit"
else
    git commit -m "FlowNiri $VERSION"
fi
git tag -f "$TAG"
git push origin "$BRANCH"
git push -f origin "$TAG"

# ---- 4. create the GitHub release on the FlowNiri repo -------------------
gh release create "$TAG" "$OUT" \
    --repo "$REL_REPO" \
    --title "FlowNiri $VERSION" \
    --notes "$NOTES"

echo
echo "-> release: https://github.com/$REL_REPO/releases/tag/$TAG"
gh release view "$TAG" --repo "$REL_REPO" --json url --jq .url
