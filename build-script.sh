#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

"$DIR/cross-tools/build-script.sh"
"$DIR/depkgs/build-script.sh"

exit 0
