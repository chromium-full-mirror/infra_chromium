# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library providing project configuration."""

load("//nodes.star", "nodes")

# Store project settings both on a node and in a lucicfg.var so that the
# settings can be accessed during both the graph construction (var) and the
# graph traversal phases (node)
_PROJECT_SETTINGS = nodes.create_singleton_node_type("project-settings")

_project_settings_var = lucicfg.var()

def _configure_project(*, name, is_main, platforms = []):
    """Configure the project for the chromium-luci libraries.

    Args:
        name: The name of the project.
        is_main: Whether the project is for the main branch.
        platforms: The platforms that the branch is enabled for. It is an error
            to set this if is_main is true: all platforms are enabled for main.
    """
    if is_main and platforms:
        fail("platforms cannot be set when is_main is true")
    settings = dict(
        name = name,
        is_main = is_main,
        platforms = platforms,
    )
    _project_settings_var.set(struct(**settings))
    _PROJECT_SETTINGS.add(props = settings)

def _project_settings():
    """Get the project settings.

    chromium_luci.configure_project must be called before this is called. This
    should be called before calling any other functions from the package to
    ensure that is the case. Can be called in in any phase of lucicfg execution.

    Returns:
        A struct with the following attributes:
            name: The name of the project
            is_main: Whether the project is for the main branch
            platforms: The platforms that the branch is enabled for if
                is_main is false.
    """
    if __native__.interpreter_context() == "GEN":
        settings = getattr(_PROJECT_SETTINGS.get(), "props", None)
    else:
        settings = _project_settings_var.get()
    if not settings:
        fail("chromium_luci.configure_project must be executed")
    return settings

chromium_luci = struct(
    configure_project = _configure_project,
    project_settings = _project_settings,
)
