//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES.
//
//===----------------------------------------------------------------------===//

// <random>

// template<class _IntType = int>
// class uniform_int_distribution

// result_type min() const;

#include <cuda/std/__random_>
#include <cuda/std/cassert>

#include "test_macros.h"

int main(int, char**)
{
  {
    using D = cuda::std::uniform_int_distribution<>;
    D d(3, 8);
    assert(d.min() == 3);
  }

  return 0;
}
