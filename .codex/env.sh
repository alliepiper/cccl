pip install pre-commit lit
pre-commit install --install-hooks

pushd /tmp
wget https://apt.kitware.com/kitware-archive.sh
chmod 755 kitware-archive.sh
sudo ./kitware-archive.sh
popd

#!/usr/bin/env bash
# Minimal CUDA multi-version installer: nvcc + cuRAND (runtime+dev)
# Targets Ubuntu (generic via /etc/os-release) and supports amd64/arm64.
# Installs ONLY the versions in CUDA_VERSIONS and only nvcc + cuRAND.
# Exposes: set_cuda_version XX.Y|latest  (switches /usr/local/cuda -> /usr/local/cuda-XX.Y)

set -euo pipefail

# -----------------------------
# Requested CTK versions:
# -----------------------------
CUDA_VERSIONS=(12.9)

# --- sudo helper ---
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

# --- Distro/arch → NVIDIA repo path ---
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || -z "${VERSION_ID:-}" ]]; then
  echo "This script supports Ubuntu only; detected ID='${ID:-?}' VERSION_ID='${VERSION_ID:-?}'" >&2
  exit 1
fi
UBU_NUM="${VERSION_ID//./}"                # e.g., 24.04 -> "2404"
CUDA_REPO_TAG="ubuntu${UBU_NUM}"

case "$(dpkg --print-architecture)" in
  amd64) REPO_ARCH="x86_64" ;;
  arm64) REPO_ARCH="arm64"  ;;
  *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;;
esac

REPO_BASE="https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_REPO_TAG}/${REPO_ARCH}"
KEY_DEB="cuda-keyring_1.1-1_all.deb"

# --- Add NVIDIA APT repo keyring (idempotent) ---
if ! dpkg -s cuda-keyring >/dev/null 2>&1; then
  echo "Adding NVIDIA CUDA apt keyring for ${CUDA_REPO_TAG}/${REPO_ARCH}..."
  wget -q "${REPO_BASE}/${KEY_DEB}" -O "/tmp/${KEY_DEB}"
  $SUDO dpkg -i "/tmp/${KEY_DEB}"
fi
$SUDO apt-get update -y

# --- Base build tools (host compiler/headers) ---
$SUDO apt-get install -y --no-install-recommends build-essential

# --- Helpers ---
find_latest_nvcc_suffix() {
  # Returns e.g. "13-0"
  local tail
  tail="$(apt-cache search '^cuda-nvcc-[0-9]+-[0-9]+$' \
    | awk '{print $1}' \
    | sed -E 's/^cuda-nvcc-([0-9]+-[0-9]+)$/\1/' \
    | sort -V | tail -n1)"
  if [[ -z "$tail" ]]; then
    echo "No cuda-nvcc packages found for ${CUDA_REPO_TAG}" >&2
    return 1
  fi
  printf '%s' "$tail"
}

pkg_exists() {
  # True if a package name exists in apt metadata
  apt-cache show "$1" >/dev/null 2>&1
}

install_if_exists() {
  # Install the first package name that exists from the args list
  local name
  for name in "$@"; do
    if pkg_exists "$name"; then
      echo "Installing $name ..."
      $SUDO apt-get install -y --no-install-recommends "$name"
      return 0
    fi
  done
  echo "WARNING: None of these packages exist: $*" >&2
  return 1
}

# --- Install nvcc + cuRAND for requested versions ---
declare -A done_n
for ver in "${CUDA_VERSIONS[@]}"; do
  # Resolve nvcc suffix (X-Y) and dotted (X.Y)
  if [[ "$ver" == "latest" ]]; then
    nvcc_suffix="$(find_latest_nvcc_suffix)"     # e.g., "13-0"
    dotted="${nvcc_suffix/-/.}"                  # "13.0"
  else
    dotted="$ver"                                 # "12.9"
    nvcc_suffix="${dotted//./-}"                  # "12-9"
  fi

  nvcc_pkg="cuda-nvcc-${nvcc_suffix}"
  if [[ -n "${done_n[$nvcc_pkg]:-}" ]]; then
    echo "Skipping duplicate request for $nvcc_pkg"
    continue
  fi

  curand_pkg="libcurand-dev-${nvcc_suffix}"
  nvml_pkg="cuda-nvml-dev-${nvcc_suffix}"
  cupti_pkg="cuda-cupti-dev-${nvcc_suffix}"
  nvrtc_pkg="cuda-nvrtc-dev-${nvcc_suffix}"

  echo "==== Installing CTK $dotted ===="
  install_if_exists "$nvcc_pkg"
  install_if_exists "$curand_pkg"
  install_if_exists "$nvml_pkg"
  install_if_exists "$cupti_pkg"
  install_if_exists "$nvrtc_pkg"

  done_n[$nvcc_pkg]=1
done

# --- Version switcher: points /usr/local/cuda -> /usr/local/cuda-XX.Y
set_cuda_version() {
  local want="$1" suffix dotted dir target
  if [[ "$want" == "latest" ]]; then
    suffix="$(find_latest_nvcc_suffix)" || return 1
    dotted="${suffix/-/.}"
  else
    dotted="$want"
  fi
  dir="/usr/local/cuda-${dotted}"
  if [[ ! -d "$dir" ]]; then
    echo "ERROR: CUDA directory not found: $dir" >&2
    return 2
  fi

  # Try update-alternatives if configured
  if command -v update-alternatives >/dev/null 2>&1; then
    if $SUDO update-alternatives --list cuda >/dev/null 2>&1; then
      echo "Selecting CUDA alternative -> $dir"
      $SUDO update-alternatives --set cuda "$dir" || true
    fi
  fi

  # Ensure the symlink regardless
  target="/usr/local/cuda"
  if [[ ! -L "$target" || "$(readlink -f "$target")" != "$(readlink -f "$dir")" ]]; then
    echo "Linking $target -> $dir"
    $SUDO ln -sfn "$dir" "$target"
  fi

  # Export for current non-login shell
  export PATH="/usr/local/cuda/bin:${PATH}"
  export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"

  # Persist environment for future shells
  $SUDO bash -c 'cat >/etc/profile.d/cuda-path.sh' <<'EOF'
# Managed by minimal CUDA installer
export PATH="/usr/local/cuda/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
EOF

  echo "Active CUDA set to: $dir"
  command -v nvcc >/dev/null 2>&1 && nvcc --version || true
}

# --- Activate 'latest' by default ---
set_cuda_version 12.9

sudo apt install -y --no-install-recommends cmake sccache
