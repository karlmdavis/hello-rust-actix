#!/bin/bash

##
# This script can be run to compile the application. It's used by the
# `glitch/start.sh` script and also by the Travis CI build.
##
echo "TRACE: Running 'glitch/build.sh'..."

# Have the script exit with an error if any of the commands below return a non-zero result in `$?`.
set -e

# Ensure that piped errors aren't ignored.
set -o pipefail

# Ensure that attempts to use unbound variables cause errors.
set -u

set -o allexport
source glitch/env.sh
set +o allexport


##
# Use the Rust toolchain to compile the server.
##

# First, verify that cargo is installed and ready to go.
if [ -f "${RUST_INSTALL_DIR}/bin/cargo" ]; then
  echo "TRACE: $(${RUST_INSTALL_DIR}/bin/cargo --version)"
else
  >&2 echo 'ERROR: Cargo not available (the `glitch/install.sh` script must have failed).'
  exit 1
fi

# Compile in release mode.
echo 'TRACE: Compiling dependencies and this project with Cargo...'
pkill cargo || true; pkill rustc || true
cargo build --release
echo 'TRACE: Compiled dependencies and this project with Cargo.'

echo "TRACE: Completed 'glitch/build.sh' in ${SECONDS} seconds."
