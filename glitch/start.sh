#!/usr/bin/dumb-init /bin/bash

##
# Glitch runs this script when first starting a container to run the app,
# and again when any of the files in `watch.json`'s `restart` section are
# modified.
#
# This script was derived from `${APP_TYPES_DIR}/custom/install.sh`,
# as of 2019-02-12.
##

# Have the script exit with an error if any of the commands below return a non-zero result in `$?`.
set -e

# Ensure that piped errors aren't ignored.
set -o pipefail

# Ensure that attempts to use unbound variables cause errors.
set -u

source ${APP_TYPES_DIR}/utils.sh
set -o allexport
source glitch/env.sh
set +o allexport


##
# Use the Rust toolchain to compile and launch the server.
#
# Note: The `$PORT` environment variable specifies the port to run the server on (should be `3000` for all Glitch apps).
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
time cargo build
echo 'TRACE: Compiled dependencies and this project with Cargo.'

# Launch the server.
echo 'TRACE: Launching project application/server in background...'
${CARGO_TARGET_DIR}/debug/${PROJECT_NAME} &
echo 'TRACE: Launched project application/server.'

# This script's process must not return while the server is running, as
# otherwise Glitch will try to launch it again.
wait $!
cleanup $?
