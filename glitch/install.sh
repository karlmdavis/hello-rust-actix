#!/bin/bash

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
echo "TRACE: Running 'glitch/install.sh'..."

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
# Download and "install" a more recent version of Rust, which Actix requires.
#
# Note: I wasn't able to get rustup working, so we're going to install Rust manually, per <https://forge.rust-lang.org/other-installation-methods.html>.
##

RUST_INSTALLER_ARCHIVE="${WORKING_DIR}/${RUST_NAME}.tar.gz"
RUST_INSTALLER_DIR="${WORKING_DIR}/${RUST_NAME}-installer"

if [ ! -d "${RUST_INSTALL_DIR}" ]; then
  try_restore_working_dir_from_s3_cache
fi

if [ ! -d "${RUST_INSTALL_DIR}" ]; then

  if [ ! -f "${RUST_INSTALLER_ARCHIVE}" ]; then
    echo "TRACE: Downloading '${RUST_INSTALLER_ARCHIVE}'..."
    curl -s -o "${RUST_INSTALLER_ARCHIVE}" "https://static.rust-lang.org/dist/${RUST_NAME}.tar.gz"
    echo "TRACE: Downloaded '${RUST_INSTALLER_ARCHIVE}'."
  fi

  if [ ! -f "${RUST_INSTALLER_DIR}/install.sh" ]; then
    echo "TRACE: Extracting '${RUST_INSTALLER_ARCHIVE}'..."
    rm -rf "${RUST_INSTALLER_DIR}"
    cd "${WORKING_DIR}"
    tar -xzf "${RUST_NAME}.tar.gz" || { >&2 echo "WARN: Failed to extract '${RUST_INSTALLER_ARCHIVE}', so removing it."; rm "${RUST_NAME}.tar.gz"; exit 1; }
    mv "${RUST_NAME}/" "${RUST_NAME}-installer"
    cd ~
    echo "TRACE: Extracted '${RUST_INSTALLER_DIR}'..."
  fi

  echo "TRACE: Installing Rust to '${RUST_INSTALL_DIR}'..."
  "${RUST_INSTALLER_DIR}/install.sh" --destdir="${RUST_INSTALL_DIR}" --prefix=

  rm "${RUST_INSTALLER_ARCHIVE}"
  rm -rf "${RUST_INSTALLER_DIR}"

  echo "TRACE: Installed Rust to '${RUST_INSTALL_DIR}'."
fi

# Install sccache, a distributed build cache for Rust and Cargo.
sccache_install

echo "TRACE: Completed 'glitch/install.sh' in ${SECONDS} seconds."
