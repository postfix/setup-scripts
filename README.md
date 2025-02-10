# setup-scripts
A collection of scripts for automating software installation and update


## Table of Contents

*   [Scripts](#scripts)
*   [Usage](#usage)
*   [Contributing](#contributing)
*   [License](#license)

## Scripts

## Usage


### `onnx_install.sh`

This script installs the ONNX Runtime (https://onnxruntime.ai/). It downloads 1.19.2 version by default, the specified version, (or latest if `--latest` is used), installs it to `/opt/onnxruntime` by default.  It sets up the necessary environment variables.

**`onnx_install.sh` Usage:**

    ```bash
    ./onnx_install.sh [options]
    ```

    **Options for `onnx_install.sh`:**

    *   `--latest`: Install the latest ONNX Runtime version.
    *   `--version <version>`: Install a specific ONNX Runtime version (e.g., `./onnx_install.sh --version 1.18.0`).
    *   `--dry-run`: Perform a dry run. The file will be downloaded and its checksum verified, but ONNX Runtime will not be installed.
    *   `--install-dir <directory>`: Specify the installation directory for ONNX Runtime (default: `/opt/onnxruntime`).

    **Examples:**

    *   Install the latest version: `./onnx_install.sh --latest`
    *   Install a specific version: `./onnx_install.sh --version 1.18.0`
    *   Perform a dry run: `./onnx_install.sh --dry-run`
    *   Install to a custom directory: `./onnx_install.sh --install-dir /usr/local/onnx`


### `go_install.sh`

This script installs or updates to the latest stable version the Go programming language. It downloads the latest stable release, sets up the necessary environment variables, and configures Go.

    **`go_install.sh` Usage:**

    ```bash
    ./go_install.sh [options]
    ```

    **Options for `go_install.sh`:**

    *   `--dry-run`: Perform a dry run. Show what would be done without making any changes.
    *   `--install-dir <directory>`: Specify the installation directory for Go (default: `/usr/local`). If a directory other than `/usr/local` is provided, Go will be installed to that directory directly.  For example, `./go_install.sh --install-dir /opt/go` will install Go to `/opt/go`, not `/opt/go/go`.
    *   `-h` or `--help`: Display this help message.

    You may need to use `sudo` before the script execution if it requires root privileges. For example: `sudo ./go_install.sh` or `sudo ./onnx_install.sh --latest`

## Contributing

Contributions are highly appreciated! If you have any improvements, bug fixes, or new features to add, please submit a pull request. Please ensure your code follows the existing style and includes appropriate tests.

## License

[ Apache 2.0.]
