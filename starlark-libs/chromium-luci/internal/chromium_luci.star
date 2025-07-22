# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library providing project configuration."""

load("//nodes.star", "nodes")
load("//targets-internal/pyl-generators.star", "register_pyl_generators")

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

def _configure_project(*, name, is_main, platforms = [], ref = "refs/heads/main", relative_path = None):
    """Configure the project for the chromium-luci libraries.

    Args:
        name: The name of the project.
        is_main: Whether the project is for the main branch.
        platforms: The platforms that the branch is enabled for. It is an error
            to set this if is_main is true: all platforms are enabled for main.
        ref: The ref of the repo containing the project.
        relative_path: The path of the repo containing the project relative to
            the top-level repo.
    """
    if is_main and platforms:
        fail("platforms cannot be set when is_main is true")
    _PROJECT_SETTINGS.set(
        name = name,
        is_main = is_main,
        platforms = platforms,
        ref = ref,
        relative_path = relative_path,
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

_PER_BUILDER_OUTPUT_SETTINGS = _settings(
    "per_builder_outputs-settings",
    required_configure = "chromium_luci.configure_per_builder_outputs",
)

def _configure_per_builder_outputs(*, root_dir):
    """Configure per-builder outputs for the project.

    Args:
        root_dir: The root directory in the generated output directory under
            which per-builder outputs will be generated. Must be a non-empty
            string.
    """
    if not root_dir or type(root_dir) != type(""):
        fail("root_dir must be a non-empty string")
    _PER_BUILDER_OUTPUT_SETTINGS.set(root_dir = root_dir)

def _per_builder_outputs_settings():
    """Get the per-builder output settings.

    chromium_luci.configure_per_builder_outputs must be called before this is
    called.

    Returns:
        A struct with the following attributes:
            root_dir: The root directory in the generated output directory under
                which per-builder outputs will be generated.
    """
    return _PER_BUILDER_OUTPUT_SETTINGS.get()

_BOOTSTRAP_SETTINGS = _settings("bootstrap-settings", default = struct(
    top_level = None,
))

def _configure_bootstrap(*, top_level_host, top_level_project, top_level_ref):
    """Configure the bootstrap library.

    Configure the top-level repo for bootstrapping a dependency project.

    Args:
        top_level_host: The gitiles host that hosts the top-level project.
        top_level_project: The name of the top-level project
            (e.g. "chromium/src").
        top_level_ref: The ref of the top-level project.
    """
    _BOOTSTRAP_SETTINGS.set(top_level = struct(
        host = top_level_host,
        project = top_level_project,
        ref = top_level_ref,
    ))

def _bootstrap_settings():
    """Get the bootstrap settings.

    Returns:
        A struct with the following attributes:
            top_level: If chromium_luci.configure_bootstrap was called, a struct
                with the following attributes:
                    host: The gitiles host that hosts the top-level project.
                    project: The name of the top-level project.
                    ref: The ref of the top-level project.
                Otherwise, None
    """
    return _BOOTSTRAP_SETTINGS.get()

_BUILDER_CONFIG_SETTINGS = _settings("builder_config-settings", default = struct(
    exempted_gardened_mirrors_in_cq_builders = {},
    mega_cq_excluded_builders = {},
    mega_cq_excluded_gardener_rotations = {},
    standalone_trybot_excluded_builder_groups = {},
    standalone_trybot_excluded_builders = {},
))

def _configure_builder_config(
        *,
        exempted_gardened_mirrors_in_cq_builders = {},
        mega_cq_excluded_builders = {},
        mega_cq_excluded_gardener_rotations = {},
        standalone_trybot_excluded_builder_groups = {},
        standalone_trybot_excluded_builders = {}):
    """Configure the builder_config library.

    Args:
        exempted_gardened_mirrors_in_cq_builders: A list of bucket-qualified
            builder names (e.g. "Ci/Linux Builder") of builders without any
            gardener rotations that will not cause an error if mirrored by a CQ
            builder.
        mega_cq_excluded_builders: A list of simple builder names (e.g.
            "linux-rel") of builders that will not be included on the mega CQ.
        mega_cq_excluded_gardener_rotations: A list of gardener rotations for
            which any builders that are part of the rotation will not be
            included on the mega CQ.
        standalone_trybot_excluded_builder_groups: A list of builder groups that
            are allowed to declare try builders that do not declare any mirrors.
        standalone_trybot_excluded_builders: A list of simple builder names
            (e.g. "linux-rel") of try builders that do not need to declare
            mirrors.
    """
    _BUILDER_CONFIG_SETTINGS.set(
        exempted_gardened_mirrors_in_cq_builders = exempted_gardened_mirrors_in_cq_builders,
        mega_cq_excluded_builders = mega_cq_excluded_builders,
        mega_cq_excluded_gardener_rotations = mega_cq_excluded_gardener_rotations,
        standalone_trybot_excluded_builder_groups = standalone_trybot_excluded_builder_groups,
        standalone_trybot_excluded_builders = standalone_trybot_excluded_builders,
    )

def _builder_config_settings():
    """Get the builder_config settings.

    Returns:
        A struct with the following attributes:
            exempted_gardened_mirrors_in_cq_builders: A list of bucket-qualified
                builder names (e.g. "Ci/Linux Builder") of builders without any
                gardener rotations that will not cause an error if mirrored by a
                CQ builder.
            mega_cq_excluded_builders: A list of simple builder names (e.g.
                "linux-rel") of builders that will not be included on the mega
                CQ.
            mega_cq_excluded_gardener_rotations: A list of gardener rotations
                for which any builders that are part of the rotation will not be
                included on the mega CQ.
            standalone_trybot_excluded_builder_groups: A list of builder groups
                that are allowed to declare try builders that do not declare any
                mirrors.
            standalone_trybot_excluded_builders: A list of simple builder names
                (e.g. "linux-rel") of try builders that do not need to declare
                mirrors.
    """
    return _BUILDER_CONFIG_SETTINGS.get()

_BUILDER_HEALTH_INDICATORS_SETTINGS = _settings(
    "builder_health_indicators-settings",
    required_configure = "chromium_luci.configure_builder_health_indicators",
)

def _configure_builder_health_indicators(
        *,
        unhealthy_period_days,
        pending_time_p50_min,
        exempted_from_contact_builders = {}):
    """Configure the builder_health_indicators library.

    Args:
        unhealthy_period_days: The period in days to take data from to compute
            health metrics in the default health specs.
        pending_time_p50_min: The threshold above which the P50 pending time
            will be considered unhealthy in the default health specs.
        exempted_from_contact_builders: A dict mapping bucket name to a list of
            builders within that bucket which do not need to specify
            contact_email.
    """
    _BUILDER_HEALTH_INDICATORS_SETTINGS.set(
        unhealthy_period_days = unhealthy_period_days,
        pending_time_p50_min = pending_time_p50_min,
        exempted_from_contact_builders = exempted_from_contact_builders,
    )

def _builder_health_indicators_settings():
    """Get the builder_health_indicators settings.

    chromium_luci.configure_builder_health_indicators must be called before
    calling this.

    Returns:
        A struct with the following attributes:
            unhealthy_period_days: The period in days to take data from to
                compute health metrics.
            pending_time_p50_min: The threshold above which the P50 pending time
                will be considered unhealthy.
            exempted_from_contact_builders: A dict mapping bucket name to a list
                of builders within that bucket which do not need to specify
                contact_email.
    """
    return _BUILDER_HEALTH_INDICATORS_SETTINGS.get()

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

_GARDENER_ROTATIONS_SETTINGS = _settings("gardener_rotations-settings")

def _configure_gardener_rotations(*, rotation_files_path):
    """Configure the gardener_rotations library.

    This will result in rotation files being generated for each gardener
    rotation that contains the list of builders that are part of the rotation.
    These files can have restricted ownership to prevent builders from being
    added to or removed from a rotation without the rotation owners being
    informed.

    project.configure must also be called. Rotation files are only generated if
    is_main is true.

    Args:
        rotation_files_path: A non-empty relative path within the generated
            directory to generate the rotation files into.
    """
    if not rotation_files_path:
        fail("rotation_files_path must be a non-empty string")
    _GARDENER_ROTATIONS_SETTINGS.set(
        rotation_files_path = rotation_files_path,
    )

def _gardener_rotations_settings():
    """Get the gardener_rotations settings.

    Returns:
        If chromium_luci.configure_gardener_rotations was called, a struct with
        the following attributes:
            rotations_file_path: The relative path within the generated
            directory to generate the rotation files into.
        Otherwise, None.
    """
    return _GARDENER_ROTATIONS_SETTINGS.get()

_TARGETS_SETTINGS = _settings("targets-settings", default = struct(
    autoshard_exceptions = {},
))

def _get_autoshard_exceptions(autoshard_exceptions_file):
    if not autoshard_exceptions_file:
        return {}
    autoshard_exceptions = {}
    raw_exceptions = json.decode(io.read_file(autoshard_exceptions_file))
    for builder_group, raw_exceptions_for_group in raw_exceptions.items():
        exceptions_for_group = autoshard_exceptions.setdefault(builder_group, {})
        for builder, raw_exceptions_for_builder in raw_exceptions_for_group.items():
            exceptions_for_builder = exceptions_for_group.setdefault(builder, {})
            for test, raw_exception_for_test in raw_exceptions_for_builder.items():
                exceptions_for_builder[test] = int(raw_exception_for_test["shards"])
    return autoshard_exceptions

def _configure_targets(*, generate_pyl_files = False, autoshard_exceptions_file = None):
    """Configure the targets library.

    Args:
        generate_pyl_files: A boolean indicating whether pyl files should be
            generated containing the reusable target declarations (variant,
            tests, legacy suites). This enables test and suite definitions to be
            shared between builders that have been migrated to starlark and
            those that have not.
        autoshard_exceptions_file: Path to a file containing autoshard
            exceptions to be applied to generated tests. The file should be a
            json file with a dict where the shards for a test running on a
            builder in a builder group can be found by dereferencing the
            following keys: builder group -> builder -> test -> "shards". An
            entry for each builder group, builder and test isn't required, but
            any entries present must contain the "shards" key.
    """
    if generate_pyl_files:
        register_pyl_generators()
    return _TARGETS_SETTINGS.set(
        autoshard_exceptions = _get_autoshard_exceptions(autoshard_exceptions_file),
    )

def _targets_settings():
    """Get the targets settings.

    Returns:
        A struct with the following attributes:
            autoshard_exceptions: A dict where the shards for a test running on
                a builder in a builder group can be gound by dereferincing the
                following keys: builder group -> builder -> test -> "shards".
                Entries might not be present for all builder groups, builders
                and tests but any entries present will contain the "shards" key.
    """
    return _TARGETS_SETTINGS.get()

chromium_luci = struct(
    configure_project = _configure_project,
    project_settings = _project_settings,
    configure_per_builder_outputs = _configure_per_builder_outputs,
    per_builder_outputs_settings = _per_builder_outputs_settings,

    # library-specific configuration
    configure_bootstrap = _configure_bootstrap,
    bootstrap_settings = _bootstrap_settings,
    configure_builder_config = _configure_builder_config,
    builder_config_settings = _builder_config_settings,
    configure_builder_health_indicators = _configure_builder_health_indicators,
    builder_health_indicators_settings = _builder_health_indicators_settings,
    configure_gardener_rotations = _configure_gardener_rotations,
    gardener_rotations_settings = _gardener_rotations_settings,
    configure_gn_args = _configure_gn_args,
    gn_args_settings = _gn_args_settings,
    configure_targets = _configure_targets,
    targets_settings = _targets_settings,
)
