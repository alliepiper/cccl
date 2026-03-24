# Add a CMake Preset

**Applicable areas:** `CMakePresets.json`, `cmake/`

## When to use

A new CCCL subproject or build configuration needs a standardized preset.

## Steps

1. **Open `CMakePresets.json`** in the repo root.

2. **Add a configure preset** inheriting from `base`:

   ```json
   {
     "name": "myproject-cpp20",
     "inherits": "base",
     "displayName": "myproject-cpp20",
     "cacheVariables": {
       "CMAKE_CXX_STANDARD": "20",
       "CCCL_ENABLE_MYPROJECT": "ON"
     }
   }
   ```

   Naming convention: `<project>` or `<project>-cpp<std>`.

3. **Add build/test presets** if needed (reference the configure preset by name).

4. **Verify:**

   ```bash
   cmake --preset myproject-cpp20
   cmake --build --preset myproject-cpp20
   ctest --preset myproject-cpp20
   ```

5. **Update CI scripts** if the preset will be used by CI
   (`ci/build_common.sh` or project-specific wrappers).

## Key details

- Build directories: `build/${CCCL_BUILD_INFIX}/${presetName}`
- `CCCL_BUILD_INFIX` is set by devcontainers for toolchain isolation
- `CCCL_ENABLE_UNSTABLE` must be ON for experimental features (cudax)
- Architecture defaults to `all-major-cccl` from the base preset
