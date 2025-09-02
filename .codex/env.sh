#!/usr/bin/env bash

# This script sets up the OpenAI Codex environment to be able
# to configure and build the CCCL project.
#
# This is based on an LTS Ubuntu image with some common development
# utilities pre-installed. This script adds a toolchain, CCCL build
# dependencies, and utilities like pre-commit.
#
# Running tests that require GPUs are not supported.

set -x
set -euo pipefail

# -----------------------------
# Configuration section
# -----------------------------

# CTK version to activate after installation
: "${CTK_DEFAULT_VERSION:=latest}"

# CTK versions to install
# Note: Use proper array defaulting; the prior form produced
# a literal string like ("12.9"), which led to package names
# such as cuda-nvcc-(12-9).
if [[ -z "${CTK_INSTALL_VERSIONS+x}" ]]; then
  CTK_INSTALL_VERSIONS=("$CTK_DEFAULT_VERSION")
fi

# CUDA packages (without version suffix)
CUDA_PACKAGES=(
  cuda-cupti-dev
  cuda-nvcc
  cuda-nvml-dev
  cuda-nvrtc-dev
  libcurand-dev
  libnvjitlink-dev
)

# Non-CUDA apt packages
APT_PACKAGES=(
  build-essential
  cmake
  sccache # We aren't configured to use our AWS buckets, but makes our scripting more robust.
  libtbb-dev
)

# Pip dependencies
PIP_PACKAGES=(
  pre-commit
  lit
)

# -----------------------------
# Helper functions
# -----------------------------

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

retry() {
  attempts=$1
  wait_secs=$2
  shift 2
  cmd="$@"
  until $cmd; do
    ((attempts--))
    if [[ $attempts -le 0 ]]; then
      echo "Command failed after $attempts attempts: $cmd" >&2
      return 1
    fi
    echo "Retrying in $wait_secs seconds..."
    sleep "$wait_secs"
  done
}

suffix_from_version() {
  local ver="$1"
  if [[ "$ver" == "latest" ]]; then
    apt-cache search '^cuda-nvcc-[0-9]+-[0-9]+$' \
      | awk '{print $1}' \
      | sed -E 's/^cuda-nvcc-([0-9]+-[0-9]+)$/\1/' \
      | sort -V | tail -n1
  else
    echo "${ver//./-}"
  fi
}

install_ctk() {
  local ver="$1" suffix pkg
  suffix="$(suffix_from_version "$ver")"
  for pkg in "${CUDA_PACKAGES[@]}"; do
    $SUDO apt-get install -y --no-install-recommends "${pkg}-${suffix}"
  done
  select_ctk "$ver"
}

select_ctk() {
  local ver="$1" suffix dotted dir target bin_path lib_path
  suffix="$(suffix_from_version "$ver")"
  dotted="${suffix/-/.}"
  dir="/usr/local/cuda-${dotted}"
  if [[ ! -d "$dir" ]]; then
    echo "ERROR: CUDA directory not found: $dir" >&2
    return 1
  fi

  bin_path="/usr/local/cuda/bin"
  lib_path="/usr/local/cuda/lib64"

  $SUDO update-alternatives --install /usr/local/cuda cuda "$dir" 100
  $SUDO update-alternatives --set cuda "$dir"

  target="/usr/local/cuda"
  $SUDO ln -sfn "$dir" "$target"

  case ":$PATH:" in
    *":${bin_path}:"*) ;;
    *) export PATH="${bin_path}:${PATH}" ;;
  esac

  case ":${LD_LIBRARY_PATH:-}:" in
    *":${lib_path}:"*) ;;
    *) export LD_LIBRARY_PATH="${lib_path}:${LD_LIBRARY_PATH:-}" ;;
  esac

  cat <<'EOF' | $SUDO tee /etc/profile.d/cuda-path.sh >/dev/null
# Managed by .codex/env.sh
case ":$PATH:" in
  *":/usr/local/cuda/bin:"*) ;;
  *) export PATH="/usr/local/cuda/bin:$PATH" ;;
esac
case ":${LD_LIBRARY_PATH:-}:" in
  *":/usr/local/cuda/lib64:"*) ;;
  *) export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}" ;;
esac
EOF

  command -v nvcc >/dev/null 2>&1 && nvcc --version || true
}

# -----------------------------
# Apt setup
# -----------------------------

# Add Kitware repo for latest CMake
if ! grep -q kitware /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
  tmp="$(mktemp -d)"
  pushd "$tmp" >/dev/null
  wget https://apt.kitware.com/kitware-archive.sh
  chmod 755 kitware-archive.sh
  $SUDO ./kitware-archive.sh
  popd >/dev/null
  rm -rf "$tmp"
fi

# Add NVIDIA CUDA repo
source /etc/os-release
UBU_NUM="${VERSION_ID//./}"
CUDA_REPO_TAG="ubuntu${UBU_NUM}"
case "$(dpkg --print-architecture)" in
  amd64) REPO_ARCH="x86_64" ;;
  arm64) REPO_ARCH="arm64" ;;
  *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac
REPO_BASE="https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO_TAG}/${REPO_ARCH}"
KEY_DEB="cuda-keyring_1.1-1_all.deb"
if ! dpkg -s cuda-keyring >/dev/null 2>&1; then
  wget -q "${REPO_BASE}/${KEY_DEB}" -O "/tmp/${KEY_DEB}"
  $SUDO dpkg -i "/tmp/${KEY_DEB}"
fi

# Update apt once after all repos are added
retry 5 2 $SUDO apt-get update -y

# -----------------------------
# Installation
# -----------------------------
for ver in "${CTK_INSTALL_VERSIONS[@]}"; do
  install_ctk "$ver"
done

select_ctk "$CTK_DEFAULT_VERSION"

$SUDO apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"

pip install "${PIP_PACKAGES[@]}"
pre-commit install --install-hooks
