# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library providing a settings facility.

Settings provide configurable values that can be accessed both during the
graph-construction phase and the graph-traversal phase.
"""

# Avoid adding additional loads for files within the package, see note in
# //internal/experiments.star
load("//nodes.star", "nodes")

# Store project settings both on a node and in a lucicfg.var so that the
# settings can be accessed during both the graph construction (var) and the
# graph traversal phases (node)
def _settings(node_kind, *, required_configure = None, default = None):
    """Create a settings type.

    Args:
        node_kind: A string identifying the settings type.
        required_configure: A string identifying the name of the function that
            needs to be called before the settings can be retrieved. If
            required_configure is set and the get method of the settings type is
            called before the set method of the settings type, then fail will be
            called with an error message identifying the function to be called.
            Cannot be set if default is set.
        default: A struct containing the default setting values. If default is
            set and the get method of the settings type is called before the set
            method of the settings type, then default will be returned. Cannot
            be set if required_configure is set.

    Returns:
        A settings type that can be used to set and get the settings values.

        The type has the following methods:
        * set(**kwargs): Set the settings values. Can only be called once.
        * get(): Get the settings values. If the set method was called, a struct
            will be returned with attributes corresponding to the kwargs passed
            to set. If the set method was called, then the behavior is as
            follows:
            * If required_configure was set, then fail will be called
                identifying the function that needs to be called to set the
                settings.
            * If default was set, default will be returned.
            * Otherwise, None will be returned.
    """
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

settings = struct(
    settings = _settings,
)
