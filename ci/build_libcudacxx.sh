#!/bin/bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/build_common.sh"

print_environment_details

if [[ "${CXX_STANDARD}" == "headers" ]]; then
    PRESET="libcudacxx-headers"
else
    PRESET="libcudacxx-cpp${CXX_STANDARD}"
fi
CMAKE_OPTIONS=""

configure_and_build_preset libcudacxx "$PRESET" "$CMAKE_OPTIONS"

print_time_summary
