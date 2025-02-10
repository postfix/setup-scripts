#!/bin/bash

set -e
set -u

# Default installation directory
if [[ -z "${INSTALL_DIR:-}" ]]; then
  INSTALL_DIR="/usr/local"
  GO_ROOT="$INSTALL_DIR/go"
else
  GO_ROOT="$INSTALL_DIR"
fi

PROFILE_SCRIPT="/etc/profile.d/goenv.sh"
DRY_RUN=false

# Function to check dependencies
check_dependencies() {
  for cmd in wget curl sha256sum tar; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: $cmd is required but not installed."
      exit 1
    fi
  done
}

# Function to retrieve the latest Go version without jq
get_latest_version() {
  local version
  version=$(curl -s https://go.dev/dl/?mode=json | grep -oE '"version":\s*"go[0-9.]+"' | head -1 | sed -E 's/"version":\s*"go([0-9.]+)"/\1/')

  [[ -z "$version" ]] && version=$(curl -s https://go.dev/VERSION | awk '{print $1}' | sed 's/go//')

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Invalid version format retrieved."
    exit 1
  fi
  echo "$version"
}

# Function to ensure files are downloaded to the current directory
download_file() {
  local url="$1"
  local output="$2"
  local max_attempts=3
  local attempt=0

  echo "Downloading $output from $url..."
  echo "Current working directory: $(pwd)"
  echo "Files before download:"
  ls -lh

  until curl -fsSL --retry 3 --output "$output" "$url" || [[ $attempt -ge $max_attempts ]]; do
    echo "Download failed. Retrying in 3 seconds..."
    sleep 3
    ((attempt++))
  done

  if [[ $attempt -eq $max_attempts ]]; then
    echo "Download failed after multiple attempts."
    exit 1
  fi

  echo "Files after download:"
  ls -lh
}


# Function to verify checksum
verify_checksum() {
  echo "Fetching checksum from https://go.dev/dl/?mode=json..."

  # Ensure jq is installed
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq and rerun the script."
    exit 1
  fi

  # Extract checksum for the correct OS & architecture
  json_data=$(curl -s https://go.dev/dl/?mode=json)

  expected_checksum=$(echo "$json_data" | jq -r \
    --arg filename "$go_filename" \
    '.[] | .files[] | select(.filename == $filename) | .sha256')

  # Debug output to verify correct extraction
  echo "✅ Expected Filename: $go_filename"
  echo "✅ Extracted Checksum: $expected_checksum"

  # Ensure we got a valid checksum
  if [[ -z "$expected_checksum" || "$expected_checksum" == "null" ]]; then
    echo "Error: Failed to retrieve checksum for $go_filename."
    exit 1
  fi

  # Compute the checksum of the downloaded file
  actual_checksum=$(sha256sum "$go_filename" | awk '{print $1}')
  echo "✅ Calculated Checksum: $actual_checksum"

  if [[ "$expected_checksum" != "$actual_checksum" ]]; then
    echo "❌ Checksum mismatch! Expected: $expected_checksum, Got: $actual_checksum"
    exit 1
  fi

  echo "✅ Checksum verification successful!"
}



# Function to extract Go archive safely
extract_go() {
  echo "Extracting Go archive..."

  # Remove old Go installation if it exists
  if [ -d "$GO_ROOT" ]; then
    sudo rm -rf "$GO_ROOT"
  fi

  # Correct extraction behavior based on the install directory
  if [[ "$INSTALL_DIR" == "/usr/local" ]]; then
    echo "Installing Go to /usr/local (default behavior)"
    sudo tar -C /usr/local -xzf "$go_filename"
  else
    echo "Installing Go to custom directory: $INSTALL_DIR"
    sudo tar -xzf "$go_filename" -C "$(dirname "$INSTALL_DIR")"
  fi
}


# Function to create `/etc/profile.d/goenv.sh`
create_env_script() {
  echo "Setting up Go environment variables in $PROFILE_SCRIPT..."
  
  sudo bash -c "cat > $PROFILE_SCRIPT" <<EOF
export GOROOT=$INSTALL_DIR
export PATH=\$GOROOT/bin:\$PATH
EOF

  sudo chmod 644 "$PROFILE_SCRIPT"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      echo "Dry-run mode enabled. No changes will be made."
      ;;
    --install-dir)
      INSTALL_DIR="$2"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# Start script execution
check_dependencies

echo "Checking for Go installation..."
if command -v go &> /dev/null; then
  installed_version=$(go version | awk '{print $3}' | sed 's/go//')
  latest_version=$(get_latest_version)

  if [[ "$installed_version" == "$latest_version" ]]; then
    echo "Go is already up-to-date (version $installed_version)."
    exit 0
  else
    echo "Updating Go from $installed_version to $latest_version..."
  fi
else
  echo "Go is not installed. Installing the latest version..."
  latest_version=$(get_latest_version)
fi

# Detect OS and architecture
go_os=$(uname -s | tr '[:upper:]' '[:lower:]')
go_arch=$(uname -m | tr '[:upper:]' '[:lower:]')
case "$go_arch" in
  x86_64) go_arch="amd64" ;;
  aarch64) go_arch="arm64" ;;
esac

go_filename="go${latest_version}.${go_os}-${go_arch}.tar.gz"
go_url="https://go.dev/dl/${go_filename}"

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry-run mode: Would have downloaded $go_url"
  exit 0
fi

download_file "$go_url" "$go_filename"
verify_checksum
extract_go
create_env_script

echo "Go installation/update complete. Version: $(go version | awk '{print $3}')"

exit 0

