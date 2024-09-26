#!/bin/bash

set -euo pipefail

pip install numpy

git clone git@github.com:NVIDIA/MatX.git
cd MatX
mkdir build
cd build
cmake -G Ninja .. -DMATX_BUILD_TESTS=ON -DMATX_BUILD_EXAMPLES=ON -DMATX_BUILD_BENCHMARKS=ON -DMATX_EN_CUTENSOR=ON
cmake --build
