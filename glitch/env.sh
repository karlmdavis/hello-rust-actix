##
# Defines the variables, functions, etc. shared between
# `install.sh` and `start.sh`.
##

RUST_NAME=rust-1.32.0-x86_64-unknown-linux-gnu
PATH=/tmp/${RUST_NAME}/bin:${PATH}

CARGO_HOME=/tmp/cargo/home
PATH=$CARGO_HOME:$PATH
mkdir -p $CARGO_HOME
CARGO_TARGET_DIR=/tmp/cargo/target
mkdir -p $CARGO_TARGET_DIR

# Enables and configures sccache for Rust Cargo builds.
# Note: sccache must be installed before this is called, or builds will fail.
SCCACHE_VERSION=0.2.8
sccache_enable() {
  if [ -z "${SCCACHE_BUCKET:-}" ] || [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    >&2 echo 'WARN: Rust/Cargo builds cannot be cached in S3 but will be cached locally (so slow, boo!).'
    SCCACHE_DIR=/tmp/cargo/sccache
    mkdir -p ${SCCACHE_DIR}
    RUSTC_WRAPPER=${CARGO_HOME}/bin/sccache
  else
    echo 'INFO: Rust/Cargo builds will be cached in S3 (so fast, yay!).'
    #SCCACHE_BUCKET=<bucket_name>
    #AWS_ACCESS_KEY_ID=<TODO>
    #AWS_SECRET_ACCESS_KEY=<TODO>
  fi

  echo 'TRACE: Launching/restarting sccache...'
  pkill -f sccache || true
  ${CARGO_HOME}/bin/sccache --start-server &> /tmp/cargo/sccache/sccache-server.log
  echo 'TRACE: Launched/restarted sccache.'
}

# Tries to download a pre-built sccache binary from S3 and if not available,
# uses Cargo to download, compile, and install it from source.
sccache_install() {
  # TODO: Eventually, we need to pull sccache from a cache, too, as it itself takes a hilariously long time (about 28 minutes) to compile.
  if [ ! -f ${CARGO_HOME}/bin/sccache ]; then
    sccache_install_from_source
    
    set -o allexport
    sccache_enable
    set +o allexport
  fi
}

# Downloads, compiles, and installs sccache from source, using Cargo.
sccache_install_from_source() {
  echo 'TRACE: Downloading, compiling, and installing sccache...'
  # When running `cargo install`, the CARGO_TARGET_DIR variable is only honored if it's a relative path.
  cd /tmp
  CARGO_TARGET_DIR_TEMP=$CARGO_TARGET_DIR
  export CARGO_TARGET_DIR=./cargo/target
  time cargo install sccache --version ${SCCACHE_VERSION}
  export CARGO_TARGET_DIR=$CARGO_TARGET_DIR_TEMP
  cd ~
  echo 'TRACE: Installed sccache.'
}

if [ -f ${CARGO_HOME}/bin/sccache ]; then
  sccache_enable
fi