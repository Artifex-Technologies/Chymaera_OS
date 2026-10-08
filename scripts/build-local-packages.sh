#!/usr/bin/env bash
# Builds every PKGBUILD under packages/pkgbuilds/ and adds the results to
# the local [chymaera] pacman repo at repo/x86_64/. Run this as a regular
# user before scripts/build.sh (whenever a submodule like packages/sarina
# has moved to a new commit, or a vendored PKGBUILD like calamares changes).
#
# Requires: Arch Linux (or an Arch container), base-devel, git.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "error: makepkg refuses to run as root — run this as a regular user" >&2
  echo "  (it uses sudo internally for any pacman dependency installs it needs)." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pkgbuilds_dir="$repo_root/packages/pkgbuilds"
repo_dir="$repo_root/repo/x86_64"

if [[ ! -f "$repo_root/packages/sarina/go/go.mod" ]]; then
  echo "error: packages/sarina submodule looks empty — run:" >&2
  echo "  git submodule update --init --recursive" >&2
  exit 1
fi

mkdir -p "$repo_dir"

for pkgbuild_dir in "$pkgbuilds_dir"/*/; do
  name="$(basename "$pkgbuild_dir")"
  echo "==> Building $name"
  (
    cd "$pkgbuild_dir"
    rm -rf pkg src
    makepkg -f -s --noconfirm
    cp -f ./*.pkg.tar.zst "$repo_dir/"
  )
done

repo-add "$repo_dir/chymaera.db.tar.gz" "$repo_dir"/*.pkg.tar.zst

echo "Built and added to local repo: $repo_dir"
