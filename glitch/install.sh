#!/usr/bin/dumb-init /bin/bash

##
# Glitch runs this script when first starting a container to run the app,
# and again when any of the files in `watch.json`'s `install` section are
# modified.
#
# Bootstraps the Rust toolchain.
#
# Note: This is **hilariously** slow from a cold start: don't just go get a cup of coffee,
# but feel free to head out to the coffee shop. Improvements should be possible with the
# use of an external cache (e.g. S3 and sccache).
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
# Download and "install" a more recent version of Rust, which Actix requires.
#
# Note: I wasn't able to get rustup working, so we're going to install Rust manually, per <https://forge.rust-lang.org/other-installation-methods.html>.
##
echo "TRACE: Running 'glitch/install.sh'..."

if [ ! -f "${WORKING_DIR}/${RUST_NAME}.tar.gz" ]; then
  echo "TRACE: Downloading '${WORKING_DIR}/${RUST_NAME}.tar.gz'..."
  time curl -s -o "${WORKING_DIR}/${RUST_NAME}.tar.gz" "https://static.rust-lang.org/dist/${RUST_NAME}.tar.gz"
  echo "TRACE: Downloaded '${WORKING_DIR}/${RUST_NAME}.tar.gz'."
fi

if [ ! -f "${WORKING_DIR}/${RUST_NAME}-installer/install.sh" ]; then
  echo "TRACE: Extracting '${WORKING_DIR}/${RUST_NAME}.tar.gz'..."
  cd "${WORKING_DIR}"
  rm -rf "${RUST_NAME}"
  rm -rf "${RUST_NAME}-installer"
  time tar -xzf "${RUST_NAME}.tar.gz" || { >&2 echo "WARN: Failed to extract '${WORKING_DIR}/${RUST_NAME}.tar.gz', so removing it."; rm "${RUST_NAME}.tar.gz"; exit 1; }
  mv "${RUST_NAME}/" "${RUST_NAME}-installer"
  cd ~
  echo "TRACE: Extracted '${WORKING_DIR}/${RUST_NAME}-installer'..."
fi

if [ ! -d "/${WORKING_DIR}/${RUST_NAME}" ]; then
  echo "TRACE: Installing Rust to '${WORKING_DIR}/${RUST_NAME}'..."
  time "${WORKING_DIR}/${RUST_NAME}-installer/install.sh" --destdir="${WORKING_DIR}/${RUST_NAME}" --prefix=
  echo "TRACE: Installed Rust to '/tmp/${RUST_NAME}'."
fi

# Install sccache, a distributed build cache for Rust and Cargo.
sccache_install

echo "TRACE: Completed 'glitch/install.sh'."
