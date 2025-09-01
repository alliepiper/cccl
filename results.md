# Header Test Integration Results

## Commands Run
- `pre-commit run --files libcudacxx/cmake/header_test_internal.cpp.in libcudacxx/cmake/header_test_public.cpp.in libcudacxx/cmake/libcudacxxHeaderTesting.cmake results.md`
- `ci/build_libcudacxx.sh -configure -cxx g++ -std 17 -arch 70`
- `ci/test_libcudacxx.sh -configure -cxx g++ -std 17 -arch 70`
- `ninja -C build/libcudacxx-cpp17 libcudacxx/CMakeFiles/libcudacxx.headers.internal.dir/headers/libcudacxx.headers.internal/cuda/__random/random_bijection.h.cu.o`
- `ninja -C build/libcudacxx-cpp17 libcudacxx/CMakeFiles/libcudacxx.headers.public.dir/headers/libcudacxx.headers.public/cuda/__numeric/overflow_cast.h.cu.o`
- `ninja -C build/libcudacxx-cpp17 libcudacxx/CMakeFiles/libcudacxx.headers.host.dir/headers/libcudacxx.headers.host/cuda/__random/feistel_bijection.h.cpp.o`
- `cmake --build --preset libcudacxx-cpp17 --target libcudacxx.headers.public_sm70`

## Results
- All configuration and targeted builds succeeded after relocating header test templates into the `cmake` directory.

## Suggested Fixes
- None.
