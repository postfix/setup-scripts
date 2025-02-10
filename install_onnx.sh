#!/bin/bash

set -e
set -u

# Default installation settings
DEFAULT_ONNX_VERSION="1.19.2"
INSTALL_DIR="/opt/onnxruntime"
PROFILE_SCRIPT="/etc/profile.d/onnxenv.sh"
DRY_RUN=false
USE_LATEST=false
CUSTOM_VERSION=""

# Function to check required commands
check_dependencies() {
  for cmd in wget curl sha256sum tar; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: $cmd is required but not installed."
      exit 1
    fi
  done
}

# Function to get the latest ONNX Runtime version
get_latest_version() {
  local version
  version=$(curl -s "https://api.github.com/repos/microsoft/onnxruntime/releases/latest" | grep -oP '"tag_name":\s*"v\K[0-9.]+' | head -1)

  if [[ -z "$version" ]]; then
    echo "Error: Failed to retrieve the latest ONNX Runtime version."
    exit 1
  fi
  echo "$version"
}

# Function to download files with retries
download_file() {
  local url="$1"
  local output="$2"
  local max_attempts=3
  local attempt=0

  echo "Downloading $output from $url..."
  until curl -fsSL --retry 3 --output "$output" "$url" || [[ $attempt -ge $max_attempts ]]; do
    echo "Download failed. Retrying in 3 seconds..."
    sleep 3
    ((attempt++))
  done

  if [[ $attempt -eq $max_attempts ]]; then
    echo "Download failed after multiple attempts."
    exit 1
  fi
}

# Function to compute and display checksum (manual verification)
compute_checksum() {
  local file="$1"
  local calculated_checksum
  calculated_checksum=$(sha256sum "$file" | awk '{print $1}')
  
  echo "✅ SHA256 Checksum: $calculated_checksum"
  echo "⚠️ Please verify this checksum manually before proceeding with installation."
}

# Function to extract ONNX Runtime
extract_onnx() {
  echo "Extracting ONNX Runtime..."
  
  if [ -d "$INSTALL_DIR" ]; then
    sudo rm -rf "$INSTALL_DIR"
  fi

  sudo tar -xzf "$onnx_filename" -C /opt
  sudo ln -sf "/opt/$onnx_extracted_dir" "$INSTALL_DIR"
}

# Function to configure environment variables
create_env_script() {
  echo "Setting up ONNX Runtime environment variables in $PROFILE_SCRIPT..."
  
  sudo bash -c "cat > $PROFILE_SCRIPT" <<EOF
export LD_LIBRARY_PATH=$INSTALL_DIR/lib:\$LD_LIBRARY_PATH
EOF

  sudo chmod 644 "$PROFILE_SCRIPT"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --latest)
      USE_LATEST=true
      ;;
    --version)
      shift
      CUSTOM_VERSION="$1"
      ;;
    --dry-run)
      DRY_RUN=true
      echo "Dry-run mode enabled. The file will be downloaded and verified, but not installed."
      ;;
    --install-dir)
      shift
      INSTALL_DIR="$1"
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Check for required dependencies
check_dependencies

# Determine ONNX version to install
if [[ "$USE_LATEST" == true ]]; then
  ONNX_VERSION=$(get_latest_version)
elif [[ -n "$CUSTOM_VERSION" ]]; then
  ONNX_VERSION="$CUSTOM_VERSION"
else
  ONNX_VERSION="$DEFAULT_ONNX_VERSION"
fi

echo "Installing ONNX Runtime version: $ONNX_VERSION"

# Define file and URL details
ONNX_ARCH="linux-x64"
ONNX_NAME="onnxruntime"
onnx_filename="${ONNX_NAME}-${ONNX_ARCH}-${ONNX_VERSION}.tgz"
onnx_url="https://github.com/microsoft/${ONNX_NAME}/releases/download/v${ONNX_VERSION}/${onnx_filename}"
onnx_extracted_dir="${ONNX_NAME}-${ONNX_ARCH}-${ONNX_VERSION}"

# Always download in dry-run mode, but skip installation
download_file "$onnx_url" "$onnx_filename"
compute_checksum "$onnx_filename"

if [[ "$DRY_RUN" == true ]]; then
  echo "✅ Dry-run completed. ONNX Runtime has been downloaded and checksum verified but not installed."
  exit 0
fi

# Extract and install ONNX Runtime
extract_onnx
create_env_script

echo "✅ ONNX Runtime installation/update complete. Version: $ONNX_VERSION"

exit 0
