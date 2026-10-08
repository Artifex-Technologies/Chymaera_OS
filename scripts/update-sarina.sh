#!/usr/bin/env bash
# Advances packages/sarina (the Sarina submodule) to the latest commit on
# its default branch and stages the pointer bump. Review with
# `git -C packages/sarina log --oneline @{u}..` beforehand if you want to see
# what's changing first; commit the result yourself when it looks right.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

git -C "$repo_root" submodule update --remote --merge packages/sarina
git -C "$repo_root" add packages/sarina

echo "packages/sarina advanced to:"
git -C "$repo_root/packages/sarina" log -1 --oneline
echo
echo "Staged. Review with 'git diff --cached packages/sarina' and commit when ready."
