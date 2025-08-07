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

def _restrict_to_projects(projects, description):
    project = _project_settings().name
    if project not in projects:
        fail(
            "{} can only be used in the following projects: {}"
                .format(description, sorted(projects)),
            trace = stacktrace(skip = 2),
        )

_PROJECT_SETTINGS = _settings(
    "project-settings",
    required_configure = "chromium_luci.configure_project",
)

def _configure_project(*, name, is_main, platforms = {}, ref = "refs/heads/main", relative_path = None):
    """Configure the project for the chromium-luci libraries.

    Args:
        name: The name of the project.
        is_main: Whether the project is for the main branch.
        platforms: A dict of platforms that are enabled for the the branch. The
            keys of the dict should be one of the branches.platform values, with
            the values being a struct with the gardener_rotation attribute which
            is either None or a string with the name of the gardener rotation to
            set for the builder on the branch. It is an error to set this if
            is_main is true: all platforms are enabled for main.
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

def _normalize_os(os):
    if type(os) == type(""):
        return os
    if type(os) == type(struct()) and hasattr(os, "get_dimension"):
        if os.override_key != None:
            fail("overridable dimension {} cannot be used as an override value".format(os.name))
        return os.get_dimension(None, None)
    fail("{} can't be used as an override value, a string or non-overridable os constant is required".format(os))

def _os_dimension_overrides(*, default = None, overrides = {}):
    """Define overrides for an os value.

    Dimension values can be specified as a string or a non-overridable os
    constant. A string will be used directly as the dimension, whereas an os
    constant will be converted to its associated dimension.

    Args:
        default: The default dimension value to use.
        overrides: A dict mapping bucket names to dicts mapping builder names to
            the dimension value to use for the associated builder.

    Returns:
        A struct that can be used as a value in the os_dimension_overrides
        argument of chromium_luci.configure_builders.
    """
    return struct(
        __os_dimension_overrides__ = True,
        default = None if default == None else _normalize_os(default),
        overrides = {k: _normalize_os(v) for k, v in overrides},
    )

def _normalize_overrides(overrides):
    if hasattr(overrides, "__os_dimension_overrides__"):
        return overrides

    return _os_dimension_overrides(default = overrides)

_BUILDERS_SETTINGS = _settings("builders-settings", default = struct(
    builder_group_reuse_bucket_allowlist = [],
    exempted_from_description_builders = {},
    os_dimension_overrides = _os_dimension_overrides(),
))

def _configure_builders(
        *,
        builder_group_reuse_bucket_allowlist = [],
        exempted_from_description_builders = {},
        os_dimension_overrides = _os_dimension_overrides()):
    """Configure the builders library.

    Args:
        builder_group_reuse_bucket_allowlist: A list of buckets that are allowed
            to reuse builder groups from other buckets. Ordinarily it is an
            error if a builder group is used within multiple buckets.
        exempted_from_description_builders: A dict mapping bucket names to a
            collection of names of builders within the bucket that do not need
            to specify a description.
        os_dimension_overrides: A dict mapping overridable os constants to
            overrides providing the dimension value. The values in the dict can
            be strings, os constants or structs returned from
            chromium_luci.os_dimension_overrides. A string will be used as the
            dimension value for all builders. An os constant will be converted
            to its associated dimension to be used for all builders.
    """
    for os in os_dimension_overrides:
        if os.override_key == None:
            fail("{} is not an overridable os value".format(os.name))
    _BUILDERS_SETTINGS.set(
        builder_group_reuse_bucket_allowlist = builder_group_reuse_bucket_allowlist,
        exempted_from_description_builders = exempted_from_description_builders,
        os_dimension_overrides = {
            k.override_key: _normalize_overrides(v)
            for k, v in os_dimension_overrides.items()
        },
    )

def _builders_settings():
    """Get the builders settings.

    Returns:
        A struct with the following attributes:
            builder_group_reuse_bucket_allowlist: A list of buckets that are
                allowed to reuse builder groups from other buckets. Ordinarily
                it is an error if a builder group is used within multiple
                buckets.
            exempted_from_description_builders: A dict mapping bucket names to a
                collection of names of builders within the bucket that do not
                need to specify a description.
            os_dimension_overrides: A dict mapping overridable os constants to
                chromium_luci.os_dimension_overrides structs determining the
                dimension value(s) to be used by the os constant.
    """
    return _BUILDERS_SETTINGS.get()

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

_CI_SETTINGS = _settings(
    "ci-settings",
    required_configure = "chromium.luci.configure_ci",
)

def _configure_ci(
        *,
        test_results_bq_dataset_name,
        resultdb_index_by_timestamp = False,
        main_console_view = None,
        # TODO: crbug.com/435248194 - Remove this once M139 and lower have been
        # turned down
        include_headless_shell_wpt_in_blink_web_test_results = True):
    """Configure the ci library.

    Args:
        test_results_bq_dataset_name: The name of dataset to upload test results
            to. CI builders will upload results to tables with names of the form
            chrome-luci-data.<test_results_bq_dataset_name>.<pre>ci_test_results
            with <pre> depending on the test ID.
        resultdb_index_by_timestamp: A boolean indicating whether ResultDb
            should index results for CI builders by timestamp, which allows for
            searching for results by timestamp.
        main_console_view: The name of a main console view to add all CI
            builders to.
        include_headless_shell_wpt_in_blink_web_test_results: Whether to include
            a regex to match tests with an ID ending in headless_shell_wpt/ in
            blink web tests results. This is restricted to existing projects to
            prevent unnecessary changes to the generated config.
    """
    if not include_headless_shell_wpt_in_blink_web_test_results:
        _restrict_to_projects(
            ["chrome-m132", "chrome-m138", "chrome-m139"],
            "include_headless_shell_wpt_in_blink_web_test_results=False",
        )
    return _CI_SETTINGS.set(
        test_results_bq_dataset_name = test_results_bq_dataset_name,
        resultdb_index_by_timestamp = resultdb_index_by_timestamp,
        main_console_view = main_console_view,
        include_headless_shell_wpt_in_blink_web_test_results =
            include_headless_shell_wpt_in_blink_web_test_results,
    )

def _ci_settings():
    """Get the ci settings.

    chromium_luci.configure_ci must be called before calling this.

    Returns:
        A struct with the following attributes:
            test_results_bq_dataset_name: The name of dataset to upload test
                results to. CI builders will upload results to tables with names
                of the form chrome-luci-data.<test_results_bq_dataset_name>.<pre>ci_test_results
                with <pre> depending on the test ID.
            resultdb_index_by_timestamp: A boolean indicating whether ResultDb
                should index results for CI builders by timestamp, which allows
                for searching for results by timestamp.
            main_console_view: The name of a main console view to add all CI
                builders to.
    """
    return _CI_SETTINGS.get()

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

_RECIPE_EXPERIMENTS_SETTINGS = _settings(
    "recipe_experiments-settings",
    default = struct(
        require_builder_wrappers = True,
    ),
)

def _configure_recipe_experiments(*, require_builder_wrappers = True):
    """Configure the recipe_experiments library.

    Args:
        require_builder_wrappers: If True, then it will be an error if any
            builders exist that are not defined via the wrappers in the
            builders, ci or try libraries. If False, then builders can be
            defined without one of the wrappers, but the recipes will not have
            their experiments applied to those builders.
    """
    _RECIPE_EXPERIMENTS_SETTINGS.set(
        require_builder_wrappers = require_builder_wrappers,
    )

def _recipe_experiments_settings():
    """Get the recipe_experiments settings.

    Returns:
        A struct with the following attributes:
            require_builder_wrappers: If True, then it will be an error if any
                builders exist that are not defined via the wrappers in the
                builders, ci or try libraries. If False, then builders can be
                defined without one of the wrappers, but the recipes will not
                have their experiments applied to those builders.
    """
    return _RECIPE_EXPERIMENTS_SETTINGS.get()

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

_TRY_SETTINGS = _settings(
    "try-settings",
    required_configure = "chromium_luci.configure_try",
)

def _configure_try(
        *,
        test_results_bq_dataset_name,
        resultdb_index_by_timestamp = False,
        additional_default_exclude_path_regexps = [],
        # TODO: crbug.com/435248194 - Remove this once M139 and lower have been
        # turned down
        include_headless_shell_wpt_in_blink_web_test_results = True):
    """Configure the try library.

    Args:
        test_results_bq_dataset_name: The name of dataset to upload test results
            to. Try builders will upload results to tables with names of the
            form chrome-luci-data.<test_results_bq_dataset_name>.<pre>try_test_results
            with <pre> depending on the test ID.
        resultdb_index_by_timestamp: A boolean indicating whether ResultDb
            should index results for try builders by timestamp, which allows for
            searching for results by timestamp.
        additional_default_exclude_path_regexps: Additional paths regexps that
            will be excluded by the default filters for a tryjob.
        include_headless_shell_wpt_in_blink_web_test_results: Whether to include
            a regex to match tests with an ID ending in headless_shell_wpt/ in
            blink web tests results. This is restricted to existing projects to
            prevent unnecessary changes to the generated config.
    """
    if not include_headless_shell_wpt_in_blink_web_test_results:
        _restrict_to_projects(
            ["chrome-m132", "chrome-m138", "chrome-m139"],
            "include_headless_shell_wpt_in_blink_web_test_results=False",
        )
    return _TRY_SETTINGS.set(
        test_results_bq_dataset_name = test_results_bq_dataset_name,
        resultdb_index_by_timestamp = resultdb_index_by_timestamp,
        additional_default_exclude_path_regexps = additional_default_exclude_path_regexps,
        include_headless_shell_wpt_in_blink_web_test_results =
            include_headless_shell_wpt_in_blink_web_test_results,
    )

def _try_settings():
    """Get the try settings.

    chromium_luci.configure_try must be called before calling this.

    Returns:
        A struct with the following attributes:
            test_results_bq_dataset_name: The name of dataset to upload test
                results to. Try builders will upload results to tables with
                names of the form chrome-luci-data.<test_results_bq_dataset_name>.<pre>try_test_results
                with <pre> depending on the test ID.
            resultdb_index_by_timestamp: A boolean indicating whether ResultDb
                should index results for try builders by timestamp, which allows
                for searching for results by timestamp.
            additional_default_exclude_path_regexps: Additional paths regexps
                that will be excluded by the default filters for a tryjob.
    """
    return _TRY_SETTINGS.get()

chromium_luci = struct(
    configure_project = _configure_project,
    project_settings = _project_settings,
    configure_per_builder_outputs = _configure_per_builder_outputs,
    per_builder_outputs_settings = _per_builder_outputs_settings,

    # library-specific configuration
    configure_bootstrap = _configure_bootstrap,
    bootstrap_settings = _bootstrap_settings,
    configure_builders = _configure_builders,
    os_dimension_overrides = _os_dimension_overrides,
    builders_settings = _builders_settings,
    configure_builder_config = _configure_builder_config,
    builder_config_settings = _builder_config_settings,
    configure_builder_health_indicators = _configure_builder_health_indicators,
    builder_health_indicators_settings = _builder_health_indicators_settings,
    configure_ci = _configure_ci,
    ci_settings = _ci_settings,
    configure_gardener_rotations = _configure_gardener_rotations,
    gardener_rotations_settings = _gardener_rotations_settings,
    configure_gn_args = _configure_gn_args,
    gn_args_settings = _gn_args_settings,
    configure_recipe_experiments = _configure_recipe_experiments,
    recipe_experiments_settings = _recipe_experiments_settings,
    configure_targets = _configure_targets,
    targets_settings = _targets_settings,
    configure_try = _configure_try,
    try_settings = _try_settings,
)
