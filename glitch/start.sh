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
source glitch/env.sh


##
# Use the Rust toolchain to compile and launch the server.
#
# Note: The `$PORT` environment variable specifies the port to run the server on (should be `3000` for all Glitch apps).
##

# First, verify that cargo is installed and ready to go.
if [ -f /tmp/${RUST_NAME}/bin/cargo ]; then
  /tmp/${RUST_NAME}/bin/cargo --version
else
  >&2 echo 'Cargo not available (the `glitch/install.sh` script must have failed).'
  exit 1
fi
export PATH=/tmp/${RUST_NAME}/bin:${PATH}

# Compile in release mode.
echo 'Compiling dependencies and this project with Cargo...'
time cargo build --release
>&2 echo 'Compiled dependencies and this project with Cargo.'

# Launch the server.
/tmp/target/release/hello-rust-actix &

# This script's process must not return while the server is running, as
# otherwise Glitch will try to launch it again.
wait $!
cleanup $?