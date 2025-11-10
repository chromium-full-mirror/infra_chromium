# Copyright 2021 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library for handling details for bootstrapping builder properties.

Enabling bootstrapping for a builder provides versioning of the properties:
property changes for CQ builders will be applied during the CQ run and when
building a revision of code, the properties that are applied will be the
properties that were set for the builder at that revision.

This is accomplished by the use of a passthrough-style bootstrapper luciexe. The
properties specified in the starlark for the builder are written out to a
separate file. The builder's definition in cr-buildbucket.cfg is updated to use
the bootstrapper executable and the builder is updated to use the bootstrapper
and have properties set that the bootstrapper consumes. These properties enable
the bootstrapper to apply the properties from the properties file and then
execute the exe that was specified for the builder.

To enable bootstrapping for a builder, bootstrap must be set to True in its
builder definition its and it must be using a bootstrappable recipe. See
//recipes.star for more information on bootstrappable recipes.
"""

load("@stdlib//internal/graph.star", "graph")
load("@stdlib//internal/luci/common.star", "keys")
load("./internal/chromium_luci.star", _chromium_luci = "chromium_luci")
load("./nodes.star", "nodes")

# buildifier: disable=out-of-order-load
# builder_config.star and orchestrator.star have generators that modify
# properties, so load them first to ensure that the modified properties get
# written out to the property files
load("./builder_config.star", _ = "builder_config")  # @unused
load("./orchestrator.star", _2 = "register_orchestrator")  # @unused

POLYMORPHIC = "POLYMORPHIC"

_top_level = lucicfg.var(default = None)

def _set_top_level(*, host, project, ref):
    _top_level.set(struct(
        host = host,
        project = project,
        ref = ref,
    ))

bootstrap = struct(
    set_top_level = _set_top_level,
)

# Properties that will be retained in cr-buildbucket.cfg. This enables querying
# the property via buildbucket or bigquery or using it as part of an expression
# in a custom metric (properties set by the bootstrapper don't appear on the
# build). Because the value in cr-buildbucket.cfg doesn't take effect until some
# time after the change lands and buildbucket picks up the new configuration,
# there will be a lag in when the property changes for these queries.
#
# Each element is a 2-tuple containing the name of the property to keep in
# cr-buildbucket.cfg and a boolean indicating whether the property should also
# be bootstrapped. If the builder actually consumes the property then the
# property should be bootstrapped so that the builder gets the up-to-date value.
# Due to the lag mentioned above, if one of these bootstrapped properties is
# changed there will be a period of time where the builder running against HEAD
# will use the updated value of the property while buildbucket still sees the
# old value. If the property is not actually consumed by the build, not
# bootstrapping it will prevent unnecessary changes to the properties files,
# which in unnecessarily triggers builders as part of the CQ attempt.
#
# If buildbucket ever exposes input properties set by the bootstrapper, revisit
# these properties to determine whether they need to be kept in
# cr-buildbucket.cfg. Properties in cr-buildbucket.cfg will be set before the
# build runs, so any use that might need to consider pending or expired builds
# would probably want the property present in cr-buildbucket.cfg.
_NON_BOOTSTRAPPED_PROPERTIES = [
    # The led_recipes_tester recipe examines the recipe property in the input
    # properties of the build definition retrieved using led to determine which
    # builders' recipes are affected by the change. The recipe engine consumes
    # the recipe property to determine which recipe to run, so it should also be
    # bootstrapped.
    ("recipe", True),

    # Sheriff-o-Matic queries for builder_group in the input properties to find
    # builds for the main gardener rotation and Findit reads the builder_group
    # from the input properties of an analyzed build to set the builder group
    # for the target builder when triggering the rerun builder. The recipe
    # consumes this property to look up various configs, so it should also be
    # bootstrapped.
    # TODO(gbeaty) When finalized input properties are exported to BQ, remove
    # this.
    ("builder_group", True),

    # Sheriff-o-Matic will query for sheriff_rotations in the input properties
    # to determine which gardener rotation a build belongs to. The same applies
    # to gardener_rotations as we move to it. The build does not consume this
    # property, so it does not need to be bootstrapped, but it is being
    # bootstrapped to avoid unnecessary churn.
    # TODO(gbeaty) When finalized input properties are exported to BQ, remove
    # this.
    ("gardener_rotations", True),
    ("sheriff_rotations", True),

    # Export a try builder's CQ status (required, path-based) to BQ if set. The
    # build does not consume this property, so it does not need to be
    # bootstrapped, but it is being bootstrapped to avoid unnecessary churn.
    # TODO(estaab): When finalized input properties are exported to BQ, remove
    # this.
    ("cq", True),

    # The alerts_enabled property needs to be present in the input properties
    # exposed on the build proto in order for the custom metric predicate to be
    # able to evaluate it. The build does not consume this property, so it does
    # not need to be bootstrapped.
    ("alerts_enabled", False),
]

# Nodes for storing the ability of recipes to be bootstrapped
_RECIPE_BOOTSTRAPPABILITY = nodes.create_unscoped_node_type("recipe_bootstrappability")

# Nodes for storing bootstrapping information about builders
_BOOTSTRAP = nodes.create_bucket_scoped_node_type("bootstrap")

def register_recipe_bootstrappability(name, bootstrappability):
    """Register a recipe's bootstrappability.

    In order for a builder to be bootstrapped, the recipe that it runs must
    implement the bootstrapping protocol, so recipes must be explicity register
    to indicate they support the protocol.

    Args:
        name: The name of the recipe.
        bootstrappability: Either a bool indicating whether the recipe is
            bootstrappable or POLYMORPHIC to indicate that the recipe uses the
            polymorphic bootstrapping protocol, which allows it to act on behalf
            of multiple builders.
    """
    if bootstrappability not in (False, True, POLYMORPHIC):
        fail("bootstrap must be one of False, True or POLYMORPHIC")
    if bootstrappability:
        key = _RECIPE_BOOTSTRAPPABILITY.add(name, props = {
            "bootstrappability": bootstrappability,
        })
        graph.add_edge(keys.project(), key)

def register_bootstrap(bucket, name, bootstrap, executable):
    """Registers the bootstrap for a builder.

    Args:
        bucket: The name of the bucket the builder belongs to.
        name: The name of the builder.
        bootstrap: Whether or not the builder should actually be bootstrapped.
        executable: The builder's executable.
    """

    top_level = _top_level.get() or _chromium_luci.bootstrap_settings().top_level

    # The properties file will be generated for any bootstrappable recipe so
    # that if a builder is switched to be bootstrapped its property file exist
    # even if an earlier revision is built (to a certain point). The bootstrap
    # property of the node will determine whether the builder's properties are
    # overwritten to actually use the bootstrapper.
    _BOOTSTRAP.add(bucket, name, props = {
        "bootstrap": bootstrap,
        "executable": executable,
        "top_level": top_level,
    })

def _bootstrap_properties(ctx):
    """Update builder properties for bootstrapping.

    For builders whose recipe supports bootstrapping, their properties will be
    written out to a separate file. This is done even if the builder is not
    being bootstrapped so that the properties file will exist already when it is
    flipped to being bootstrapped.

    For builders that have opted in to bootstrapping, this file will be read at
    build-time and update the build's properties with the contents of the file.
    The builder's properties within the buildbucket configuration will be
    modified with the properties that control the bootstrapper itself.

    The builders that have opted in to bootstrapping is determined by examining
    the lucicfg graph to find a bootstrap node for a given builder. These nodes
    will be added by the builder function. This is done rather than writing out
    the properties file in the builder function so that the bootstrapped
    properties have any final modifications that luci.builder would perform
    (merging module-level defaults, setting global defaults, etc.).
    """
    if not graph.children(keys.project(), _RECIPE_BOOTSTRAPPABILITY.kind):
        return

    cfg = None
    for f in ctx.output:
        if f.startswith("luci/cr-buildbucket"):
            cfg = ctx.output[f]
            break
    if cfg == None:
        fail("There is no buildbucket configuration file to reformat properties")

    settings = _chromium_luci.project_settings()

    for bucket in cfg.buckets:
        if not proto.has(bucket, "swarming"):
            continue
        bucket_name = bucket.name
        for builder in bucket.swarming.builders:
            builder_name = builder.name
            bootstrap_node = _BOOTSTRAP.get(bucket_name, builder_name)
            if not bootstrap_node or bootstrap_node.props.bootstrap == False:
                continue
            executable = bootstrap_node.props.executable
            recipe_bootstrappability_node = _RECIPE_BOOTSTRAPPABILITY.get(executable)
            if not recipe_bootstrappability_node:
                continue

            builder_properties = json.decode(builder.properties)
            builder_shadow_properties = None
            if proto.has(builder, "shadow_builder_adjustments") and builder.shadow_builder_adjustments.properties:
                builder_shadow_properties = json.decode(builder.shadow_builder_adjustments.properties)
            bootstrapper_args = []

            if recipe_bootstrappability_node.props.bootstrappability == POLYMORPHIC:
                non_bootstrapped_properties = builder_properties
                non_bootstrapped_shadow_properties = builder_shadow_properties

                # TODO(gbeaty) Once all builder specs are migrated src-side,
                # remove -properties-optional
                bootstrapper_args = ["-polymorphic", "-properties-optional"]

            else:
                def get_non_bootstrapped_properties(props):
                    return {p: props[p] for p, _ in _NON_BOOTSTRAPPED_PROPERTIES if p in props}

                non_bootstrapped_properties = get_non_bootstrapped_properties(builder_properties)
                non_bootstrapped_shadow_properties = None
                if builder_shadow_properties != None:
                    non_bootstrapped_shadow_properties = get_non_bootstrapped_properties(builder_shadow_properties)

                root_out_dir = _chromium_luci.per_builder_outputs_settings().root_dir
                out_dir = "{}/{}/{}".format(root_out_dir, bucket_name, builder_name)
                properties_file = "{}/properties.json".format(out_dir)
                if bootstrap_node.props.top_level:
                    bootstrap_property = {
                        "dependency_project": {
                            "top_level_repo": {
                                "host": bootstrap_node.props.top_level.host,
                                "project": bootstrap_node.props.top_level.project,
                            },
                            "top_level_ref": bootstrap_node.props.top_level.ref,
                            "config_repo": {
                                "host": "chrome-internal.googlesource.com",
                                "project": "chrome/src-internal",
                            },
                            "config_repo_submodule_path": "internal",
                        },
                        "properties_file": "{}/{}".format(settings.config_dir, properties_file),
                    }
                else:
                    bootstrap_property = {
                        "top_level_project": {
                            "repo": {
                                "host": "chromium.googlesource.com",
                                "project": "chromium/src",
                            },
                            "ref": settings.ref,
                        },
                        "properties_file": "{}/{}".format(settings.config_dir, properties_file),
                    }

                def remove_non_bootstrapped_properties(props):
                    for p, also_bootstrap in _NON_BOOTSTRAPPED_PROPERTIES:
                        if not also_bootstrap:
                            props.pop(p, None)

                if builder_shadow_properties:
                    shadow_properties_file = "{}/shadow-properties.json".format(out_dir)
                    bootstrap_property["shadow_properties_file"] = "{}/{}".format(settings.config_dir, shadow_properties_file)
                    remove_non_bootstrapped_properties(builder_shadow_properties)
                    ctx.output[shadow_properties_file] = json.indent(json.encode(builder_shadow_properties), indent = "  ")

                non_bootstrapped_properties["$bootstrap/properties"] = bootstrap_property
                remove_non_bootstrapped_properties(builder_properties)
                ctx.output[properties_file] = json.indent(json.encode(builder_properties), indent = "  ")

            if bootstrap_node.props.bootstrap:
                non_bootstrapped_properties.update({
                    "$bootstrap/exe": {
                        "exe": json.decode(proto.to_jsonpb(builder.exe, use_proto_names = True)),
                    },
                    "led_builder_is_bootstrapped": True,
                })

                builder.properties = json.encode(non_bootstrapped_properties)
                if non_bootstrapped_shadow_properties:
                    builder.shadow_builder_adjustments.properties = json.encode(non_bootstrapped_shadow_properties)
                elif non_bootstrapped_shadow_properties != None:
                    builder.shadow_builder_adjustments.properties = None

                builder.exe.cipd_package = "infra/chromium/bootstrapper/${platform}"
                builder.exe.cipd_version = "latest"
                builder.exe.cmd = ["bootstrapper"] + bootstrapper_args

lucicfg.generator(_bootstrap_properties)
