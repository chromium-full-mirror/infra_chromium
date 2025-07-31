# Copyright 2021 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library for enabling experiments on a per-recipe basis.

For each experiment registered for a recipe, if a builder that uses the recipe
does not have the experiment set, it will be set with the percentage specified
for the recipe.

See //recipes.star for information on setting experiments for a recipe.
"""

load("@stdlib//internal/graph.star", "graph")
load("@stdlib//internal/luci/common.star", "keys")
load("./internal/chromium_luci.star", _chromium_luci = "chromium_luci")
load("./nodes.star", "nodes")

_RECIPE_EXPERIMENTS = nodes.create_unscoped_node_type("recipe_experiments")

_RECIPE_EXPERIMENTS_REF = nodes.create_bucket_scoped_node_type("recipe_experiments_ref")

def register_recipe_experiments(recipe, experiments):
    _RECIPE_EXPERIMENTS.add(recipe, props = {
        "experiments": experiments,
    })

def register_recipe_experiments_ref(bucket, builder, recipe):
    key = _RECIPE_EXPERIMENTS_REF.add(bucket, builder)
    graph.add_edge(key, _RECIPE_EXPERIMENTS.key(recipe))
    graph.add_edge(keys.project(), key)

def _set_recipe_experiments(ctx):
    if not graph.children(keys.project(), _RECIPE_EXPERIMENTS_REF.kind):
        return

    cfg = None
    for f in ctx.output:
        if f.startswith("luci/cr-buildbucket"):
            cfg = ctx.output[f]
            break
    if cfg == None:
        fail("There is no buildbucket configuration file to reformat properties")

    library_settings = _chromium_luci.recipe_experiments_settings()

    for bucket in cfg.buckets:
        if not proto.has(bucket, "swarming"):
            continue
        bucket_name = bucket.name
        for builder in bucket.swarming.builders:
            builder_name = builder.name
            recipe_experiment_ref_node = _RECIPE_EXPERIMENTS_REF.get(
                bucket_name,
                builder_name,
            )

            # The only way there wouldn't be a recipe experiment ref node is if
            # the builder was not defined using one of our wrapper functions
            if not recipe_experiment_ref_node:
                if not library_settings.require_builder_wrappers:
                    continue

                # This should be impossible, our wrappers call
                # register_recipe_experiments_ref
                fail("internal failure: builder {}/{}")

            recipe_experiments_nodes = graph.children(
                recipe_experiment_ref_node.key,
                _RECIPE_EXPERIMENTS.kind,
            )
            if len(recipe_experiments_nodes) != 1:
                fail(
                    ("internal failure: builder {}/{}" +
                     " should refer to exactly 1 recipe node: {}").format(
                        bucket_name,
                        builder_name,
                        recipe_experiments_nodes,
                    ),
                )
            recipe_experiments_node = recipe_experiments_nodes[0]
            for experiment, percentage in recipe_experiments_node.props.experiments.items():
                builder.experiments.setdefault(experiment, percentage)

lucicfg.generator(_set_recipe_experiments)
