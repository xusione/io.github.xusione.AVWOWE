#!/usr/bin/env bash
# release-flatpak.sh: build and checksum a Flatpak release. Git is left to you
# (GitKraken): the script pauses with directions whenever something needs pushing
# or publishing, then checks on GitHub that it actually arrived before continuing.
# Run on the Linux build machine, from the repo root.
#
#   bash release-flatpak.sh                  (asks for version and release notes)
#   bash release-flatpak.sh 1.1.6 "Notes"    (or pass them directly)
#
# Before running: put the new bin/AVWOWE and data/ in place.
set -euo pipefail

REPO="xusione/io.github.xusione.AVWOWE"
APP_ID="com.xusione.AVWOWE"
MANIFEST="$APP_ID.yml"
METAINFO="$APP_ID.metainfo.xml"
DEFAULT_NOTES="Bug fixes and stability improvements."

step()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
todo()  { printf '\n\033[33m%s\033[0m\n' "$*"; }
die()   { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }
pause() { echo; read -rp "Press Enter when done (Ctrl+C to stop)... " _; }

# Git identifies a file by the SHA-1 of "blob <size>\0<content>". Computing it
# locally and comparing with GitHub's API shows whether a push really landed,
# without needing git set up here.
local_blob_sha()  { { printf 'blob %s\0' "$(wc -c < "$1" | tr -d ' ')"; cat "$1"; } | sha1sum | cut -d' ' -f1; }
remote_blob_sha() { curl -fsS "https://api.github.com/repos/$REPO/contents/$1?ref=main" 2>/dev/null \
                      | grep -m1 '"sha"' | sed -E 's/.*"sha": *"([0-9a-f]+)".*/\1/' || true; }

# Pause until every listed file on GitHub's main matches the local copy.
wait_until_pushed() {
  while true; do
    pause
    local missing=()
    for f in "$@"; do
      [[ "$(remote_blob_sha "$f")" == "$(local_blob_sha "$f")" ]] || missing+=("$f")
    done
    [[ ${#missing[@]} -eq 0 ]] && { echo "Confirmed on GitHub: $*"; return; }
    echo "Not on GitHub's main branch yet: ${missing[*]}"
    echo "Check that you committed and pushed to main. GitHub can also lag a few seconds."
  done
}

[[ -f "$MANIFEST" && -f "$METAINFO" ]] || die "run this from the repo root"

tag_exists() { curl -fsIL "https://github.com/$REPO/archive/refs/tags/v$1.tar.gz" >/dev/null 2>&1; }

# Version: argument, or ask. Suggest the newest metainfo version if it was never
# published, otherwise the next patch number after it.
VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  LATEST=$(grep -m1 -oE '<release version="[0-9]+\.[0-9]+\.[0-9]+"' "$METAINFO" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
  SUGGEST=""
  if [[ -n "$LATEST" ]]; then
    if tag_exists "$LATEST"; then
      IFS=. read -r major minor patch <<< "$LATEST"
      SUGGEST="$major.$minor.$((patch + 1))"
    else
      SUGGEST="$LATEST"
    fi
  fi
  read -rp "Version to release${LATEST:+ (last in metainfo: $LATEST)} [$SUGGEST]: " VERSION
  VERSION="${VERSION:-$SUGGEST}"
fi
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.2.3, got \"$VERSION\""

# Release notes: argument, or ask. Default to the notes already in the metainfo
# for this version, if there are any.
NOTES="${2:-}"
if [[ -z "$NOTES" ]]; then
  EXISTING=$(awk -v v="$VERSION" '
    index($0, "<release version=\"" v "\"") { found = 1 }
    found && /<p>/ { sub(/.*<p>/, ""); sub(/<\/p>.*/, ""); print; exit }' "$METAINFO")
  EXISTING=$(printf '%s' "$EXISTING" | sed 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g')
  NOTE_DEFAULT="${EXISTING:-$DEFAULT_NOTES}"
  read -rp "Release notes [$NOTE_DEFAULT]: " NOTES
  NOTES="${NOTES:-$NOTE_DEFAULT}"
fi

TAG="v$VERSION"
BUNDLE="AVWOWE-$VERSION-x86_64.flatpak"
TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
echo "Releasing AVWOWE $VERSION: $NOTES"

# ---------------------------------------------------------------------------
step "1/7 Checking tools and version"
for t in curl sha256sum sha1sum flatpak-builder flatpak tar awk sed; do
  command -v "$t" >/dev/null || die "missing tool: $t"
done
[[ -f bin/AVWOWE ]] || die "bin/AVWOWE not found"
if tag_exists "$VERSION"; then
  die "release $TAG already exists on GitHub; use a new version number instead of reusing it"
fi

# ---------------------------------------------------------------------------
step "2/7 Updating metainfo and README"
if grep -q "<release version=\"$VERSION\"" "$METAINFO"; then
  echo "metainfo already has a $VERSION entry, leaving it as is"
else
  NOTES_XML=$(printf '%s' "$NOTES" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  NOTES_XML="$NOTES_XML" VERSION="$VERSION" DATE="$(date +%F)" awk '
    { print }
    /<releases>/ && !done {
      printf "    <release version=\"%s\" date=\"%s\">\n      <description>\n        <p>%s</p>\n      </description>\n    </release>\n",
        ENVIRON["VERSION"], ENVIRON["DATE"], ENVIRON["NOTES_XML"]
      done = 1
    }' "$METAINFO" > "$METAINFO.tmp" && mv "$METAINFO.tmp" "$METAINFO"
  echo "added $VERSION release entry to metainfo"
fi
sed -i -E "s/AVWOWE-[0-9]+\.[0-9]+\.[0-9]+-x86_64\.flatpak/$BUNDLE/g" README.md

# ---------------------------------------------------------------------------
step "3/7 Push the release files"
todo "In GitKraken, commit and push to main:
  - bin/AVWOWE   (must be the $VERSION build)
  - data/        (if anything in it changed)
  - $METAINFO
  - README.md
Suggested commit message: AVWOWE $VERSION"
wait_until_pushed bin/AVWOWE "$METAINFO" README.md

# ---------------------------------------------------------------------------
step "4/7 Publish the GitHub release"
todo "On github.com/$REPO: Releases > Draft a new release
  - Tag: type $TAG and choose \"Create new tag: $TAG on publish\"
  - Target: main
  - Title: AVWOWE $VERSION
  - Description (copy everything between the lines):
------------------------------------------------------------
$NOTES

Download the Flatpak bundle from https://avwowe.xusione.com/
Checksums: SHA256SUMS in this repository.
------------------------------------------------------------
  - Tick \"Set as the latest release\", then Publish"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pause
until curl -fsSL "$TARBALL_URL" -o "$TMP/src.tar.gz"; do
  echo "Release $TAG not found on GitHub yet. Check it was published, not left as a draft."
  pause
done
SRC_SHA=$(sha256sum "$TMP/src.tar.gz" | cut -d' ' -f1)
echo "source archive sha256: $SRC_SHA"

# Catch a release tagged on a commit that still has the old binary.
tar -xzf "$TMP/src.tar.gz" -C "$TMP"
TAR_BIN=$(find "$TMP" -path '*/bin/AVWOWE' -type f | head -1)
if [[ -z "$TAR_BIN" ]] || ! cmp -s "$TAR_BIN" bin/AVWOWE; then
  die "release $TAG does not contain your local bin/AVWOWE. Delete the release and its tag on GitHub, push the right binary, and run this again."
fi
echo "release contains the same bin/AVWOWE as this folder"

# ---------------------------------------------------------------------------
step "5/7 Pointing the manifest at $TAG"
sed -i -E "/io\.github\.xusione\.AVWOWE\/archive\/refs\/tags\/v[0-9.]+\.tar\.gz/{
  s|tags/v[0-9.]+\.tar\.gz|tags/$TAG.tar.gz|
  n
  s|sha256: [0-9a-f]+|sha256: $SRC_SHA|
}" "$MANIFEST"
grep -q "tags/$TAG.tar.gz" "$MANIFEST" && grep -q "sha256: $SRC_SHA" "$MANIFEST" \
  || die "could not update $MANIFEST; set the avwowe url to $TARBALL_URL and sha256 to $SRC_SHA by hand"

# ---------------------------------------------------------------------------
step "6/7 Building the bundle (dependencies are cached, only the app module rebuilds)"
flatpak-builder --repo=repo --force-clean build-dir "$MANIFEST"
flatpak build-bundle repo "$BUNDLE" "$APP_ID" --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
sha256sum "$BUNDLE" > SHA256SUMS
BUNDLE_SHA=$(cut -d' ' -f1 SHA256SUMS)

# Test before the checksum goes public, so a broken bundle can still be rebuilt.
echo
read -rp "Install the bundle and launch AVWOWE to test it now? [Y/n] " t
if [[ "$t" != [nN] ]]; then
  flatpak install --user -y "$BUNDLE"
  echo "Launching. Close AVWOWE to continue."
  flatpak run "$APP_ID" || true
  read -rp "Did it work? [y/N] " worked
  [[ "$worked" == [yY] ]] || die "stopped before publishing the checksum. The release is already on GitHub; fix the problem and rebuild."
fi
TESTED=$([[ "$t" != [nN] ]] && echo yes || echo no)

# ---------------------------------------------------------------------------
step "7/7 Push the manifest and checksum"
todo "In GitKraken, commit and push to main:
  - $MANIFEST
  - SHA256SUMS
Suggested commit message: Flatpak: build from $TAG
(Do not commit $BUNDLE, repo/ or build-dir/.)"
wait_until_pushed "$MANIFEST" SHA256SUMS

cat <<EOF

Done.
  Bundle: $PWD/$BUNDLE
  sha256: $BUNDLE_SHA

Still to do by hand:
  1. $([[ "$TESTED" == yes ]] && echo "(tested above)" || echo "Test it:  flatpak install --user $BUNDLE && flatpak run $APP_ID")
  2. Upload $BUNDLE to assets/downloads/app/flatpak/ on the site
  3. Deploy the site pages that link to $VERSION
  4. Optional: keep the last 10 AVWOWE-*.flatpak files in that folder, delete anything older
EOF
