# Copyright 2022 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library for registering builders to gardener_rotations."""

load("@stdlib//internal/graph.star", "graph")
load("@stdlib//internal/luci/common.star", "keys")
load("./internal/chromium_luci.star", _chromium_luci = "chromium_luci")
load("./internal/gardener_rotations.star", _gardener_rotations = "gardener_rotations")
load("./nodes.star", "nodes")

_GARDENER_ROTATION = nodes.create_unscoped_node_type("gardener_rotation")

_GARDENED_BUILDER = nodes.create_bucket_scoped_node_type("gardened_builder")

gardener_rotations = struct(
    rotation = lambda name, console_name, tree_closer_console: _gardener_rotations.rotation(
        name = name,
        console_name = console_name,
        tree_closer_console = tree_closer_console,
        main_only = True,
    ),
)

def register_gardener_builder(bucket, builder, gardener_rotations):
    """Register a builder with its gardener rotations.

    Args:
        bucket: The name of the bucket of the builder.
        builder: The name of the builder.
        gardener_rotations: A list of the names of gardener rotations the
            builder is a part of.
    """
    gardened_builder_key = _GARDENED_BUILDER.add(bucket, builder)
    for s in gardener_rotations:
        gardener_rotation_key = _GARDENER_ROTATION.add(s, idempotent = True)
        graph.add_edge(gardener_rotation_key, gardened_builder_key)
        graph.add_edge(keys.project(), gardener_rotation_key)

def get_gardener_rotations(bucket, builder):
    gardened_builder = _GARDENED_BUILDER.get(bucket, builder)
    if gardened_builder:
        return graph.parents(gardened_builder.key)
    return []

def _generate_gardener_rotations_files(ctx):
    settings = _chromium_luci.gardener_rotations_settings()
    if not settings:
        return

    for gardener_rotation_node in graph.children(keys.project(), _GARDENER_ROTATION.kind):
        gardened_builders = []
        for gardened_builder_node in graph.children(gardener_rotation_node.key, _GARDENED_BUILDER.kind):
            key = gardened_builder_node.key
            gardened_builders.append("{}/{}".format(key.container.id, key.id))
        gardener_rotation_file = "{}/{}.txt".format(
            settings.rotation_files_path,
            gardener_rotation_node.key.id,
        )
        ctx.output[gardener_rotation_file] = "".join(["{}\n".format(b) for b in sorted(gardened_builders)])

lucicfg.generator(_generate_gardener_rotations_files)
