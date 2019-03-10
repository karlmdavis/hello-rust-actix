#!/bin/bash

##
# Glitch runs this script when first starting a container to run the app,
# and again when any of the files in `watch.json`'s `restart` section are
# modified.
#
# This script was derived from `${APP_TYPES_DIR}/custom/install.sh`,
# as of 2019-02-12.
##
echo "TRACE: Running 'glitch/start.sh'..."

# Have the script exit with an error if any of the commands below return a non-zero result in `$?`.
set -e

# Ensure that piped errors aren't ignored.
set -o pipefail

# Ensure that attempts to use unbound variables cause errors.
set -u

# TODO Can this be removed? It just sets a couple signal traps, and I suspect the Glitch framework itself is calling it.
if [[ -f "${APP_TYPES_DIR}/utils.sh" ]]; then
  source ${APP_TYPES_DIR}/utils.sh
fi

set -o allexport
source glitch/env.sh
set +o allexport


##
# Assume things are already compiled and ready and try to launch the server.
# (If things _aren't_ compiled we'll get an error -- no big deal.)
#
# Note: The `$PORT` environment variable specifies the port to run the server on (should be `3000` for all Glitch apps).
##

# Launch the server.
echo 'TRACE: Launching project application/server in background...'
${CARGO_TARGET_DIR}/debug/${PROJECT_NAME} &
echo 'TRACE: Launched project application/server.'

echo "TRACE: Completed 'glitch/start.sh' (mostly) in ${SECONDS} seconds."

# This script's process must not return while the server is running, as
# otherwise Glitch will try to launch it again.
wait $!
cleanup $?
