#!/bin/sh
# Builds dewdiary outside the repository, so the Mac's rsync of the tree stays small, and
# puts it in ~/bin.
# Author: David M. Anderson
# Built with AI assistance (Claude, Anthropic)
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
scratch="${HOME}/.cache/dewdiary"
swift build --package-path "$here" --scratch-path "$scratch" -c release
mkdir -p "${HOME}/bin"
cp "$scratch/release/dewdiary" "${HOME}/bin/dewdiary"
echo "installed ${HOME}/bin/dewdiary"
