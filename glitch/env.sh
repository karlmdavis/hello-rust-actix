##
# Defines the variables, functions, etc. shared between
# `install.sh` and `start.sh`.
##

# Uploads the specified file to the S3 cache.
# Parameters:
#   $1: relative path to the file to upload
#   $2: S3 path/key to store the object at
upload_file_to_s3_cache() {
  if [ "${S3_CACHE_ENABLED}" != "true" ]; then >&2 echo "ERROR: S3 cache not enabled; can't upload to it."; exit 1; fi;
  file=$1
  objectPath=$2
  resource="/${AWS_S3_CACHE_BUCKET}/${objectPath}"
  contentType="application/octet-stream"
  dateValue=`date -R`
  stringToSign="PUT\n\n${contentType}\n${dateValue}\n${resource}"
  signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${AWS_SECRET_ACCESS_KEY} -binary | base64` 
  echo "TRACE: Uploading ${file} to S3 cache..."
  curl --silent -X PUT -T "${file}" \
    -H "Host: ${AWS_S3_CACHE_BUCKET}.s3.amazonaws.com" \
    -H "Date: ${dateValue}" \
    -H "Content-Type: ${contentType}" \
    -H "Authorization: AWS ${AWS_ACCESS_KEY_ID}:${signature}" \
    "https://${AWS_S3_CACHE_BUCKET}.s3.amazonaws.com/${objectPath}"
  echo "TRACE: Uploaded ${file} to S3 cache."
}

# Enables and configures sccache for Rust Cargo builds.
# Note: sccache must be installed before this is called, or builds will fail.
sccache_enable() {
  if [ "${S3_CACHE_ENABLED}" = "true" ]; then
    SCCACHE_BUCKET="${AWS_S3_CACHE_BUCKET}"
  else
    SCCACHE_DIR=/tmp/cargo/sccache
    mkdir -p ${SCCACHE_DIR}
  fi
  RUSTC_WRAPPER=${CARGO_HOME}/bin/sccache

  if [ -f ${CARGO_HOME}/bin/sccache ]; then
    echo 'TRACE: Launching/restarting sccache...'
    pkill -f sccache || true
    mkdir -p /tmp/cargo/sccache
    ${CARGO_HOME}/bin/sccache --start-server &> /tmp/cargo/sccache/sccache-server.log
    echo 'TRACE: Launched/restarted sccache.'
  else
    echo 'TRACE: Did not start sccache; not yet present.'
  fi
}

# Tries to download a pre-built sccache binary from S3 and if not available,
# uses Cargo to download, compile, and install it from source.
sccache_install() {
  if [ ! -f ${CARGO_HOME}/bin/sccache ]; then
    echo 'TRACE: Trying to download cached sccache from S3...'
    mkdir -p "${CARGO_HOME}/bin"
    wget --quiet --output-document="${CARGO_HOME}/bin/sccache" "https://s3.amazonaws.com/justdavis-glitch-rust-caching/sccache-${SCCACHE_VERSION}" || rm "${CARGO_HOME}/bin/sccache"
    if [ -f ${CARGO_HOME}/bin/sccache ]; then
      echo 'TRACE: Downloaded cached sccache from S3.'
      chmod a+x "${CARGO_HOME}/bin/sccache"
    else
      >&2 echo 'WARN: Was not able to download cached sccache from S3.'
    fi
  fi
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
  upload_file_to_s3_cache "${CARGO_HOME}/bin/sccache" "sccache-${SCCACHE_VERSION}"
}

RUST_NAME=rust-1.32.0-x86_64-unknown-linux-gnu
PATH=/tmp/${RUST_NAME}/bin:${PATH}

CARGO_HOME=/tmp/cargo/home
PATH=$CARGO_HOME:$PATH
mkdir -p $CARGO_HOME
CARGO_TARGET_DIR=/tmp/cargo/target
mkdir -p $CARGO_TARGET_DIR

SCCACHE_VERSION=0.2.8

# Check to see if an S3 bucket is available for caching.
if [ -z "${AWS_S3_CACHE_BUCKET:-}" ] || [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  >&2 echo 'WARN: Rust/Cargo builds cannot be cached in S3 but will be cached locally (so slow, boo!).'
  S3_CACHE_ENABLED=false
else
  echo 'INFO: Rust/Cargo builds will be cached in S3 (so fast, yay!).'
  S3_CACHE_ENABLED=true
fi

sccache_enable