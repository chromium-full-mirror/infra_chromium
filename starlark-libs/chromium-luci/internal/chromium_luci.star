# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library providing project configuration."""

load("//nodes.star", "nodes")

# Store project settings both on a node and in a lucicfg.var so that the
# settings can be accessed during both the graph construction (var) and the
# graph traversal phases (node)
def _settings(node_kind, *, required_configure = None, default = None):
    if required_configure and default:
        fail("cannot set both required_configure and default")
    node_type = nodes.create_singleton_node_type(node_kind)
    var = lucicfg.var()

    def set(**kwargs):
        node_type.add(props = kwargs)
        var.set(struct(**kwargs))

    def get():
        if __native__.interpreter_context() == "GEN":
            settings = getattr(node_type.get(), "props", None)
        else:
            settings = var.get()
        if settings:
            return settings
        if required_configure:
            fail("{} must be executed".format(required_configure))
        return default

    return struct(
        set = set,
        get = get,
    )

_PROJECT_SETTINGS = _settings(
    "project-settings",
    required_configure = "chromium_luci.configure_project",
)

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
    _PROJECT_SETTINGS.set(
        name = name,
        is_main = is_main,
        platforms = platforms,
    )

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
    return _PROJECT_SETTINGS.get()

_GN_ARGS_SETTINGS = _settings("gn_args-settings", default = struct(
    enable_siso_defaults = True,
))

def _configure_gn_args(*, enable_siso_defaults = True):
    """Configure the gn_args library.

    Args:
        enable_siso_defaults: If True (default), builders that set gn_args will
            have default GN args set depending on whether they are using siso
            and whether they are using the built-in RBE client:
            * if using siso, the use_siso GN arg will be set to "true"
            * if using the siso built-in RBE client, the use_reclient GN arg
                will be set to "false"
    """
    _GN_ARGS_SETTINGS.set(
        enable_siso_defaults = enable_siso_defaults,
    )

def _gn_args_settings():
    """Get the gn_args settings.

    Returns:
        If chromium_luci.configure_gn_args was called, a struct with the
        following attributes:
            enable_siso_defaults: Whether to generate default siso GN args
        Otherwise, None.
    """
    return _GN_ARGS_SETTINGS.get()

chromium_luci = struct(
    configure_project = _configure_project,
    project_settings = _project_settings,

    # library-specific configuration
    configure_gn_args = _configure_gn_args,
    gn_args_settings = _gn_args_settings,
)
