from gersemi.builtin_commands import builtin_commands


class Op:
    """Helper class to allow commands to be modified with a pipeline syntax."""

    def __init__(self, func, /, *args, **kwargs):
        self.func = func
        self.args = args
        self.kw = kwargs

    def __ror__(self, other):
        # Called when evaluating: other | Op(...)
        return self.func(other, *self.args, **self.kw)


def op(func):
    """Decorator to create an Op from a function."""

    def wrapper(*args, **kw):
        return Op(func, *args, **kw)

    return wrapper


@op
def move_keyword(command, keyword, src, dst):
    if src in command and keyword in command[src]:
        command[src].remove(keyword)
    command[dst].append(keyword)
    return command


@op
def set_max_inline_items(command, items):
    command["inlining_heuristic"] = items
    return command


command_definitions = {
    # Space before control flow conditions:
    "if ": builtin_commands["if"],
    "elseif ": builtin_commands["elseif"],
    "foreach ": builtin_commands["foreach"],
    # Patch up https://github.com/BlankSpruce/gersemi/pull/80:
    "find_package": (
        builtin_commands["find_package"]
        | move_keyword("REQUIRED", src="multi_value_keywords", dst="options")
    ),
    # Inlining heuristics:
    # Fails with: cccl/.gersemi/ext/builtins.py:command_definitions['cmake_parse_arguments']['signatures']: signature (None) has to be a string
    # https://github.com/BlankSpruce/gersemi/issues/82
    # "cmake_parse_arguments": builtin_commands["cmake_parse_arguments"] | set_max_inline_items(9999),
    "add_executable": builtin_commands["add_executable"] | set_max_inline_items(1),
    "add_library": builtin_commands["add_library"] | set_max_inline_items(1),
    "function": builtin_commands["function"] | set_max_inline_items(9999),
    "macro": builtin_commands["macro"] | set_max_inline_items(9999),
    # Don't work as expected, see https://github.com/BlankSpruce/gersemi/issues/78
    # "target_link_libraries": builtin_commands["target_link_libraries"] | set_max_inline_items(1),
    # "target_compile_definitions": builtin_commands["target_compile_definitions"] | set_max_inline_items(1),
    # "target_compile_options": builtin_commands["target_compile_options"] | set_max_inline_items(1),
    # "target_include_directories": builtin_commands["target_include_directories"] | set_max_inline_items(1),
    # "set_target_properties": builtin_commands["set_target_properties"] | set_max_inline_items(1),
}
