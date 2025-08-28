# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Internal details for the builders library."""

load("@stdlib//internal/graph.star", "graph")
load("@stdlib//internal/luci/common.star", "keys")
load("./chromium_luci.star", _chromium_luci = "chromium_luci")
load("//nodes.star", _nodes = "nodes")

_ALERTING = _nodes.create_bucket_scoped_node_type("builders|alerting")

def _register_alerting(*, bucket, name, alerts_enabled):
    """Register the alerting status of a builder.

    Args:
        bucket: The name of the bucket the builder belongs to.
        name: The name of the builder.
        alerts_enabled: A boolean indicating whether the builder should trigger
            monitoring alerts.
    """
    if alerts_enabled:
        key = _ALERTING.add(bucket, name)
        graph.add_edge(keys.project(), key)

builders = struct(
    register_alerting = _register_alerting,
)

def _generate_alerting_builders_file(ctx):
    if not _chromium_luci.builders_settings().enable_alerts_configuration:
        return

    builders = []

    for node in graph.children(keys.project(), _ALERTING.kind):
        builders.append("{}/{}".format(node.key.container.id, node.key.id))

    file_name = "{}/alerting-builders.txt".format(_chromium_luci.per_builder_outputs_settings().root_dir)
    ctx.output[file_name] = "\n".join(sorted(builders)) + "\n"

lucicfg.generator(_generate_alerting_builders_file)
