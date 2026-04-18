# Quickstart: Tiffen

## Prerequisites

- macOS 14+ on Apple Silicon
- Xcode 15+ (for Metal compiler and XCTest)
- libtiff (`brew install libtiff`)

## Build

```bash
# Clone and build
git clone <repo-url> tiffen
cd tiffen
xcodebuild -scheme tiffen -configuration Release

# Binary location
BUILD_DIR=$(xcodebuild -scheme tiffen -showBuildSettings | grep -m1 BUILT_PRODUCTS_DIR | awk '{print $3}')
```

## Basic Usage

```bash
# Normalize all TIFFs in photos/ to match base.tiff
tiffen base.tiff photos/

# Output goes to photos/normalized/ by default
ls photos/normalized/

# Specify custom output directory
tiffen base.tiff photos/ --output ~/Desktop/normalized/

# Overwrite originals (destructive — use with caution)
tiffen base.tiff photos/ --in-place

# Verbose output
tiffen base.tiff photos/ -v
```

## Run Tests

```bash
xcodebuild test -scheme tiffen -destination 'platform=macOS'
```

## Verify Installation

```bash
# Should print version
tiffen --version

# Should print usage
tiffen --help
```
