//===----------------------------------------------------------------------===//
//
// Part of libcu++, the C++ Standard Library for your entire system,
// under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES.
//
//===----------------------------------------------------------------------===//

#include <cuda/std/__memory_>
#if defined(_LIBCUDACXX_HAS_STRING)
#  include <cuda/std/string>
#endif // _LIBCUDACXX_HAS_STRING
#include <cuda/std/cassert>

#include "test_macros.h"

__host__ __device__ TEST_CONSTEXPR_CXX23 bool test()
{
  {
    cuda::std::unique_ptr<int> p1 = cuda::std::make_unique<int>(1);
    assert(*p1 == 1);
    p1 = cuda::std::make_unique<int>();
    assert(*p1 == 0);
  }

#if defined(_LIBCUDACXX_HAS_STRING)
  {
    cuda::std::unique_ptr<cuda::std::string> p2 = cuda::std::make_unique<cuda::std::string>("Meow!");
    assert(*p2 == "Meow!");
    p2 = cuda::std::make_unique<cuda::std::string>();
    assert(*p2 == "");
    p2 = cuda::std::make_unique<cuda::std::string>(6, 'z');
    assert(*p2 == "zzzzzz");
  }
#endif // _LIBCUDACXX_HAS_STRING

  return true;
}

int main(int, char**)
{
  test();
#if TEST_STD_VER >= 2023
  static_assert(test());
#endif // TEST_STD_VER >= 2023

  return 0;
}
