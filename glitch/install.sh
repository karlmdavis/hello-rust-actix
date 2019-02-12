#!/usr/bin/dumb-init /bin/bash

##
# Glitch runs this script when first starting a container to run the app,
# and again when any of the files in `watch.json`'s `install` section are
# modified.
#
# Bootstraps the Rust toolchain and compiles the project.
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
source glitch/env.sh


##
# Download and "install" a more recent version of Rust, which Actix requires.
#
# Note: I wasn't able to get rustup working, so we're going to install Rust manually, per <https://forge.rust-lang.org/other-installation-methods.html>.
##

echo "Downloading '/tmp/${RUST_NAME}.tar.gz'..."
if [ ! -f /tmp/${RUST_NAME}.tar.gz ]; then
  time curl -s -o /tmp/${RUST_NAME}.tar.gz https://static.rust-lang.org/dist/${RUST_NAME}.tar.gz
fi
echo "Downloaded '/tmp/${RUST_NAME}.tar.gz'."

echo "Extracting '/tmp/${RUST_NAME}.tar.gz'..."
if [ ! -f /tmp/${RUST_NAME}-installer/install.sh ]; then
  cd /tmp/
  rm -rf {RUST_NAME}
  rm -rf {RUST_NAME}-installer
  time tar -xzf ${RUST_NAME}.tar.gz || { echo "Failed to extract '/tmp/${RUST_NAME}.tar.gz', so removing it."; rm ${RUST_NAME}.tar.gz; exit 1; }
  mv ${RUST_NAME}/ ${RUST_NAME}-installer
  cd ~
fi
echo "Extracted '/tmp/${RUST_NAME}-installer'..."

echo "Installing Rust to '/tmp/${RUST_NAME}'..."
if [ ! -d /tmp/${RUST_NAME} ]; then
  time /tmp/${RUST_NAME}-installer/install.sh --destdir=/tmp/${RUST_NAME} --prefix=
fi
echo "Installed Rust to '/tmp/${RUST_NAME}'."

##
# Symlink the Rust working directories to `/tmp` subdirs, so we don't bloat the Glitch project space with them.
##
mkdir -p /tmp/.cargo && ln -sf /tmp/.cargo ~/.cargo
mkdir -p /tmp/target && ln -sf /tmp/target ~/target