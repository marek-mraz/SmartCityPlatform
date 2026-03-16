#!/usr/bin/env bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if a command exists
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        log_err "$1 is not installed. Please install it and try again."
    fi
}