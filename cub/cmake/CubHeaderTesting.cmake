# For every public header, build a translation unit containing `#include <header>`
# to let the compiler try to figure out warnings in that header if it is not otherwise
# included in tests, and also to verify if the headers are modular enough.
# .inl files are not globbed for, because they are not supposed to be used as public
# entrypoints.

# Meta target for all configs' header builds:
add_custom_target(cub.all.headers)

function(cub_add_header_test label definitions)
  foreach(cub_target IN LISTS CUB_TARGETS)
    cub_get_target_property(config_dialect ${cub_target} DIALECT)
    cub_get_target_property(config_prefix ${cub_target} PREFIX)

    set(headertest_target ${config_prefix}.headers.${label})

  cccl_generate_header_tests(${headertest_target} cub
      GLOBS "cub/*.cuh"
    )
    target_link_libraries(${headertest_target} PUBLIC ${cub_target})
    if (definitions)
      target_compile_definitions(${headertest_target} PRIVATE ${definitions})
    endif()
    cub_clone_target_properties(${headertest_target} ${cub_target})
    cub_configure_cuda_target(${headertest_target} RDC ${CUB_FORCE_RDC})

    add_dependencies(cub.all.headers ${headertest_target})
    add_dependencies(${config_prefix}.all ${headertest_target})
  endforeach()
endfunction()

cub_add_header_test(base "")
