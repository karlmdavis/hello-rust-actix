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
    SCCACHE_DIR="${WORKING_DIR}/cargo/sccache"
    mkdir -p "${SCCACHE_DIR}"
  fi
  RUSTC_WRAPPER="${CARGO_HOME}/bin/sccache"

  if [ -f "${CARGO_HOME}/bin/sccache" ]; then
    echo 'TRACE: Launching/restarting sccache...'
    pkill -f sccache || true
    mkdir -p "${WORKING_DIR}/cargo/sccache"
    "${CARGO_HOME}/bin/sccache" --start-server &> "${WORKING_DIR}/cargo/sccache/sccache-server.log"
    echo 'TRACE: Launched/restarted sccache.'
  else
    echo 'TRACE: Did not start sccache; not yet present.'
  fi
}

# Tries to download a pre-built sccache binary from S3 and if not available,
# uses Cargo to download, compile, and install it from source.
sccache_install() {
  if [ ! -f "${CARGO_HOME}/bin/sccache" ]; then
    echo 'TRACE: Trying to download cached sccache from S3...'
    wget --quiet --output-document="${CARGO_HOME}/bin/sccache" "https://s3.amazonaws.com/justdavis-glitch-rust-caching/sccache-${SCCACHE_VERSION}" || rm "${CARGO_HOME}/bin/sccache"
    if [ -f "${CARGO_HOME}/bin/sccache" ]; then
      echo 'TRACE: Downloaded cached sccache from S3.'
      chmod a+x "${CARGO_HOME}/bin/sccache"
    else
      >&2 echo 'WARN: Was not able to download cached sccache from S3.'
      sccache_install_from_source
    fi

    set -o allexport
    sccache_enable
    set +o allexport
  fi
}

# Downloads, compiles, and installs sccache from source, using Cargo.
sccache_install_from_source() {
  echo 'TRACE: Downloading, compiling, and installing sccache...'
  # When running `cargo install`, the CARGO_TARGET_DIR variable is only honored if it's a relative path.
  cd "${WORKING_DIR}"
  CARGO_TARGET_DIR_TEMP="${CARGO_TARGET_DIR}"
  export CARGO_TARGET_DIR="./cargo/target"
  time cargo install sccache --version "${SCCACHE_VERSION}"
  export CARGO_TARGET_DIR="${CARGO_TARGET_DIR_TEMP}"
  cd ~
  echo 'TRACE: Installed sccache.'
  upload_file_to_s3_cache "${CARGO_HOME}/bin/sccache" "sccache-${SCCACHE_VERSION}"
}

# Saves a bundle of the project's entire working dir to the S3 cache.
cache_working_dir_in_s3() {
  echo "TRACE: Saving archive of '${WORKING_DIR}' to S3 cache..."

  if [ "${S3_CACHE_ENABLED}" != "true" ]; then
    >&2 echo "S3 cache not available; unable to save '${WORKING_DIR}' bundle to it."
    exit 1
  fi

  # Compress the working directory.
  #
  # I did some compression-decompression comparisons:
  # * `tar -cz`: 530 MB archive, 3:52 minutes compression, 0:39 minutes decompression
  # * `GZIP=-9 tar -cz`: 526 MB archive, 9:47 minutes compression, 0:46 minutes decompression
  # * `tar -c | xz -6`: 385 MB archive, 32:13 minutes compression, 2:21 minutes decompression
  # * `tar -c | xz -8`: 371 MB archive, 31:21 minutes compression, 1:21 minutes decompression
  # * Note: `xa -9` couldn't be tried, as it requires more than 500 MB of RAM.
  #
  # Given the oddities there, it seems safe to say that all of this is super
  # noisy. Nonetheless, I decided to go with the `xz -8` version for now.

  tar --directory=/tmp --create rust | xz -8 > "${WORKING_DIR_CACHE_FILE}"
  echo "TRACE: Created archive of '${WORKING_DIR}'."
  upload_file_to_s3_cache "${WORKING_DIR_CACHE_FILE}" "${WORKING_DIR_CACHE_NAME}"
  rm "${WORKING_DIR_CACHE_FILE}"
  echo "TRACE: Saved archive of '${WORKING_DIR}' to S3 cache."
}

# Tries to download and restore the full working dir cache created by
# `cache_working_dir_in_s3()`. If not available, will print a warning.
try_restore_working_dir_from_s3_cache() {
  echo "TRACE: Trying to restore '${WORKING_DIR}' from S3 cache..."
  wget --quiet --output-document=- "https://s3.amazonaws.com/justdavis-glitch-rust-caching/${WORKING_DIR_CACHE_NAME}" | tar --extract --xz --directory=/tmp || true

  if [ ! -d "${WORKING_DIR}" ]; then
    >&2 echo "WARN: Was not able to download '${WORKING_DIR}' from S3 cache."
    return
  fi

  echo "TRACE: Restored '${WORKING_DIR}' from S3 cache."
}

# The name of the project.
PROJECT_NAME='hello-rust-actix'

# The directory that all Rust-related items will be installed to, compiled in,
# etc. Needs to have about 2GB of free space, so we'll use Glitch's `/tmp`
# directory, which isn't restricted to the couple hundred MB that Glitch
# project directories are.
WORKING_DIR='/tmp/rust'

WORKING_DIR_CACHE_NAME="${PROJECT_NAME}-working-dir-cache.tar.xz"
WORKING_DIR_CACHE_FILE="/tmp/${WORKING_DIR_CACHE_NAME}"

# The name of the Rust distribution to be downloaded and installed.
RUST_NAME='rust-1.32.0-x86_64-unknown-linux-gnu'
RUST_INSTALL_DIR="${WORKING_DIR}/${RUST_NAME}"
PATH="${RUST_INSTALL_DIR}/bin:${PATH}"

# Override the directory that Cargo will use for caching crates, installing
# binaries, etc.
CARGO_HOME="${WORKING_DIR}/cargo/home"
mkdir -p "${CARGO_HOME}/bin"
PATH="${CARGO_HOME}/bin:${PATH}"

# Override the directory that Cargo will place generated artifacts in.
CARGO_TARGET_DIR="${WORKING_DIR}/cargo/target"
mkdir -p "${CARGO_TARGET_DIR}"

SCCACHE_VERSION='0.2.8'

# Check to see if an S3 bucket is available for caching.
if [ -z "${AWS_S3_CACHE_BUCKET:-}" ] || [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  >&2 echo 'WARN: Rust/Cargo builds cannot be cached in S3 but will be cached locally (so slow, boo!).'
  S3_CACHE_ENABLED=false
else
  echo 'INFO: Rust/Cargo builds will be cached in S3 (so fast, yay!).'
  S3_CACHE_ENABLED=true
fi

sccache_enable
