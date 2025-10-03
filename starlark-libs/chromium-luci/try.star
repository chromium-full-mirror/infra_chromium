# Copyright 2020 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library for defining try builders.

The `try_builder` function defined in this module enables defining a builder and
the tryjob verifier for it in the same location. It can also be accessed through
`try_.builder`.

The `tryjob` function specifies the verifier details for a builder. It can also
be accessed through `try_.job`.

The `defaults` struct provides module-level defaults for the arguments to
`try_builder`. The parameters that support module-level defaults have a
corresponding attribute on `defaults` that is a `lucicfg.var` that can be used
to set the default value. Can also be accessed through `try_.defaults`.
"""

load("./args.star", "args")
load("./branches.star", "branches")
load("./builders.star", "builders", "os")
load("./internal/chromium_luci.star", _chromium_luci = "chromium_luci")
load("./internal/experiments.star", _experiments = "experiments")
load("./internal/try.star", _default_location_filters = "default_location_filters", _location_filters_without_defaults = "location_filters_without_defaults")  #@unused
load("./orchestrator.star", "SOURCELESS_BUILDER_CACHE_NAME", "register_compilator", "register_orchestrator")

default_location_filters = _default_location_filters
location_filters_without_defaults = _location_filters_without_defaults

_DEFAULT_DISABLE_REUSE_FOOTERS = [
    "Include-Ci-Only-Tests",
]

def default_owner_whitelist_group_for_cq_bots(project):
    if project.startswith("chrome"):
        return ["googlers", "project-chromium-robot-committers"]
    return []

def owner_whitelist_group_without_defaults(tryjob_builder_proto):
    project = tryjob_builder_proto.name.split("/")[0]
    default_group = default_owner_whitelist_group_for_cq_bots(project)
    return [
        g
        for g in tryjob_builder_proto.owner_whitelist_group
        if g not in default_group
    ]

# Intended to be used for the `caches` builder arg when no source checkout is
# required.
#
# Setting a cache with a "builder" path prevents buildbucket from automatically
# creating a regular builder cache with a 4 minute wait_for_warm_cache.
# `wait_for_warm_cache = None` ensures that swarming will not look for a bot
# with a builder cache.
SOURCELESS_BUILDER_CACHE = swarming.cache(
    name = SOURCELESS_BUILDER_CACHE_NAME,
    path = "builder",
    wait_for_warm_cache = None,
)

defaults = args.defaults(
    extends = builders.defaults,
    check_for_flakiness = True,
    # TODO(crbug.com/40273153) - Once we've migrated to the ResultDB-based solution
    # this should be deprecated in favor for the original check_for_flakiness
    # argument.
    check_for_flakiness_with_resultdb = True,
    cq_group = None,
    main_list_view = None,
    subproject_list_view = None,
    resultdb_bigquery_exports = [],
    # Default overrides for more specific wrapper functions. The value is set to
    # args.DEFAULT so that when they are passed to the corresponding standard
    # argument, if the more-specific default has not been set it will fall back
    # to the standard default.
    compilator_cores = args.DEFAULT,
    orchestrator_cores = args.DEFAULT,
    orchestrator_siso_remote_jobs = args.DEFAULT,
)

# TODO(crbug.com/442860599): Remove this once all tryjob usages are migrated to
# cq_settings.
def tryjob(**kwargs):
    """DEPRECATED: Use cq_settings. Specifies the details of a tryjob verifier."""
    return cq_settings(**kwargs)

def cq_settings(
        *,
        on_default_cq = False,
        disable_reuse = None,
        experiment_percentage = None,
        includable_only = False,
        location_filters = None,
        disable_reuse_footers = None,
        cancel_stale = None,
        add_default_filters = True,
        add_default_disable_reuse_footers = True,
        equivalent_builder = None,
        equivalent_builder_percentage = None,
        equivalent_builder_whitelist = None,
        omit_from_luci_cv = False,
        custom_cq_run_modes = None):
    """Specifies the settings for a builder on CQ.

    See https://chromium.googlesource.com/infra/luci/luci-go/+/HEAD/lucicfg/doc/README.md#luci.cq_tryjob_verifier
    for details on the most of the arguments.

    Args:
        on_default_cq: A bool indicating whether the builder should be on the
            default CQ.
        disable_reuse: See cq.tryjob_verifier.
        experiment_percentage: See cq.tryjob_verifier.
        includable_only: See cq.tryjob_verifier.
        location_filters: A list of cq.location_filter objects and/or strings.
            This is the same as the location_filters value of cq.tryjob_verifier
            except that strings can be provided, which will be converted to a
            cq.location_filter with path_regexp set to the provided string.
        disable_reuse_footers: A list of footer names to disable reuse for the
            builder for. This ensures that changes to those footer values will
            cause the builder to rerun with the footer change applied.
        cancel_stale: See cq.tryjob_verifier.
        add_default_filters: A bool indicating whether to add default filters
            that exclude certain directories that would have no impact when
            building chromium with the patch applied (docs, config files that
            don't take effect until landing, etc., see
            default_location_filters). This arg has no effect when
            includable_only=True, and will instead be set to False.
        add_default_disable_reuse_footers: A bool indicating whether to add
            default footers that should disable reuse for the builder
            (Include-Ci-Only-Tests, etc., see _DEFAULT_DISABLE_REUSE_FOOTERS).
        equivalent_builder: See cq.tryjob_verifier.
        equivalent_builder_percentage: See cq.tryjob_verifier.
        equivalent_builder_whitelist: See cq.tryjob_verifier.
        omit_from_luci_cv: A bool indicating whether the tryjob will be added to
            luci verifier. This is useful for the equivalent_builder which can't
            be added twice.
        custom_cq_run_modes: List of cq.run_mode names that will trigger this
            tryjob. Uses cq.MODE_DRY_RUN, cq.MODE_FULL_RUN if not specified.

    Returns:
        A struct that can be passed to the `cq_settings` argument of
        `try_.builder` to enable the builder for CQ.
    """

    if _experiments.is_enabled("try.enforce_cq_settings_exclusivity"):
        settings_args = []
        if on_default_cq:
            settings_args.append("on_default_cq")
        if location_filters:
            settings_args.append("location_filters")
        if includable_only:
            settings_args.append("includable_only")
        if len(settings_args) != 1:
            fail("exactly one of on_default_cq, location_filters or includable_only must be specified")

    def normalize_location_filter(f):
        if type(f) == type(""):
            return cq.location_filter(path_regexp = f)
        return f

    if includable_only:
        add_default_filters = False

    if location_filters:
        if includable_only:
            fail("Tryjobs with location_filters cannot be includable_only")
        location_filters = [normalize_location_filter(f) for f in location_filters]

    return struct(
        disable_reuse = disable_reuse,
        add_default_disable_reuse_footers = add_default_disable_reuse_footers,
        disable_reuse_footers = disable_reuse_footers,
        experiment_percentage = experiment_percentage,
        includable_only = includable_only,
        add_default_filters = add_default_filters,
        location_filters = location_filters,
        cancel_stale = cancel_stale,
        custom_cq_run_modes = custom_cq_run_modes,
        equivalent_builder = equivalent_builder,
        equivalent_builder_percentage = equivalent_builder_percentage,
        equivalent_builder_whitelist = equivalent_builder_whitelist,
        omit_from_luci_cv = omit_from_luci_cv,
    )

def try_builder(
        *,
        name,
        branch_selector = branches.selector.MAIN,
        check_for_flakiness = args.DEFAULT,
        check_for_flakiness_with_resultdb = args.DEFAULT,
        cq_group = args.DEFAULT,
        list_view = args.DEFAULT,
        main_list_view = args.DEFAULT,
        subproject_list_view = args.DEFAULT,
        cq_settings = None,
        tryjob = None,  # DEPRECATED in favor of cq_settings
        resultdb_bigquery_exports = args.DEFAULT,
        **kwargs):
    """Define a try builder.

    Args:
        name: name of the builder, will show up in UIs and logs. Required.
        branch_selector: A branch selector value controlling whether the builder
            definition is executed. See branches.star for more information.
        check_for_flakiness: If True, it checks for new tests in a given try
            build and reruns them multiple times to ensure that they are not
            flaky.
        # TODO(crbug.com/40273153) - Once we've migrated to the ResultDB-based
        # solution this should be deprecated in favor for the original
        # check_for_flakiness argument.
        check_for_flakiness_with_resultdb: If True, it checks for new tests in a
            given try build using resultdb as the data source, instead of the
            previous mechanism which utilized a pregenerated test history. New
            tests are rerun multiple times to ensure that they are not flaky.
        cq_group: The CQ group to add the builder to. If cq_settings is None, it
            will be added as includable_only.
        list_view: A string or list of strings identifying the ID(s) of the list
            view to add an entry to. Supports a module-level default that
            defaults to the group of the builder, if provided.
        main_list_view: A string identifying the ID of the main list view to add
            an entry to. Supports a module-level default that defaults to None.
        subproject_list_view: A string identifying the ID of the subproject list
            view to add an entry to. Supports a module-level default that
            defaults to None.
        cq_settings: An optional try_.cq_settings controlling when the builder is
            added to the CQ.
        tryjob: DEPRECATED An optional try_.job controlling when the builder is
            added to the CQ.
        resultdb_bigquery_exports: a list of resultdb.export_test_results(...)
            specifying additional parameters for exporting test results to
            BigQuery. Will always upload to the following tables in addition to
            any tables specified by the list's elements:
                chrome-luci-data.chromium.try_test_results
                chrome-luci-data.gpu_try_test_results
        **kwargs: Additional keyword args to forward on to builders.builder.
            The alerts_enabled keyword arg will be set to True if the builder
            will be added to the CQ as non-includeable-only.

    Returns:
        The lucicfg keyset for the builder, None if the builder wasn't defined
        (e.g. branch selector doesn't match current project's settings).
    """
    if cq_settings and tryjob:
        fail("try_builder cannot be called with both cq_settings and tryjob. Use cq_settings.")
    if tryjob:
        cq_settings = tryjob

    if not branches.matches(branch_selector):
        return None

    library_settings = _chromium_luci.try_settings()
    bq_dataset_name = library_settings.test_results_bq_dataset_name
    blink_web_tests_test_id_regexp = (
        "(ninja://[^/]*blink_web_tests/.+)|(ninja://[^/]*_wpt_tests/.+)"
    )
    if library_settings.include_headless_shell_wpt_in_blink_web_test_results:
        blink_web_tests_test_id_regexp += (
            "|(ninja://[^/]*headless_shell_wpt/.+)"
        )
    telemetry_gpu_test_regexp = "(ninja://(chrome|content)/test:telemetry_gpu_integration_test[^/]*/.+)"

    if _experiments.is_enabled("targets.module_scheme_regex"):
        # Regex matches ://\:blink_web_tests!webtest::accessibility#crash.html
        blink_web_tests_test_id_regexp += (
            "|(://[^/]*blink_web_tests!.+)|(://[^/]*_wpt_tests!.+)"
        )
        if library_settings.include_headless_shell_wpt_in_blink_web_test_results:
            blink_web_tests_test_id_regexp += (
                "|(://[^/]*headless_shell_wpt!.+)"
            )

        # Regex  matches:
        # ://chrome/test\:telemetry_gpu_integration_test!flat::#gpu_tests.webgl1_test.WebGL1Test.Web_arrays
        telemetry_gpu_test_regexp += r"|(://(chrome|content)/test\\:telemetry_gpu_integration_test[^/]*!.+)"

    merged_resultdb_bigquery_exports = [
        resultdb.export_test_results(
            bq_table = "chrome-luci-data.{}.try_test_results".format(bq_dataset_name),
        ),
        resultdb.export_test_results(
            bq_table = "chrome-luci-data.{}.gpu_try_test_results".format(bq_dataset_name),
            predicate = resultdb.test_result_predicate(
                # Only match the telemetry_gpu_integration_test target and its
                # Fuchsia and Android variants that have a suffix added to the
                # end. Those are caught with [^/]*. The Fuchsia version is in
                # //content/test since Fuchsia cannot depend on //chrome.
                test_id_regexp = telemetry_gpu_test_regexp,
            ),
        ),
        resultdb.export_test_results(
            bq_table = "chrome-luci-data.{}.blink_web_tests_try_test_results".format(bq_dataset_name),
            predicate = resultdb.test_result_predicate(
                # Match the "blink_web_tests" target and all of its
                # flag-specific versions, e.g. "vulkan_swiftshader_blink_web_tests".
                test_id_regexp = blink_web_tests_test_id_regexp,
            ),
        ),
    ]
    merged_resultdb_bigquery_exports.extend(
        defaults.get_value(
            "resultdb_bigquery_exports",
            resultdb_bigquery_exports,
        ),
    )

    list_view = defaults.get_value("list_view", list_view)
    if list_view == args.COMPUTE:
        list_view = defaults.get_value_from_kwargs("builder_group", kwargs)
    if type(list_view) == type(""):
        list_view = [list_view]
    list_view = list(list_view or [])
    main_list_view = defaults.get_value("main_list_view", main_list_view)
    if main_list_view:
        list_view.append(main_list_view)
    subproject_list_view = defaults.get_value("subproject_list_view", subproject_list_view)
    if subproject_list_view:
        list_view.append(subproject_list_view)

    properties = kwargs.pop("properties", {})
    properties = dict(properties)

    builders_library_settings = _chromium_luci.builders_settings()

    # If enable_alerts_configuration isn't true, don't modify alerts_enabled
    # because that will cause a failure in builders.builder
    if (builders_library_settings.enable_alerts_configuration and
        cq_settings != None and not cq_settings.omit_from_luci_cv):
        alerts_enabled = defaults.get_value_from_kwargs("alerts_enabled", kwargs)
        if alerts_enabled == args.COMPUTE:
            kwargs["alerts_enabled"] = True

    # Populate "cq" property if builder is a required or path-based CQ builder.
    # This is useful for bigquery analysis.
    if "cq" in properties:
        fail("Setting 'cq' property directly is not supported. It is " +
             "generated automatically based on cq_settings and location_filters.")
    if cq_settings != None:
        cq_reason = "required" if not cq_settings.location_filters else "path-based"
        properties["cq"] = cq_reason

        # TODO(crbug.com/40273153) - Once we've migrated to the ResultDB-based solution
        # check_for_flakiness_with_resultdb should be deprecated in favor for the
        # original check_for_flakiness argument.
        check_for_flakiness = defaults.get_value(
            "check_for_flakiness",
            check_for_flakiness,
        )
        check_for_flakiness_with_resultdb = defaults.get_value(
            "check_for_flakiness_with_resultdb",
            check_for_flakiness_with_resultdb,
        )

        flakiness = {}
        if defaults.get_value("check_for_flakiness", check_for_flakiness):
            flakiness["check_for_flakiness"] = True
        if defaults.get_value("check_for_flakiness_with_resultdb", check_for_flakiness_with_resultdb):
            flakiness["check_for_flakiness_with_resultdb"] = True
        if flakiness:
            properties["$build/flakiness"] = flakiness

    # Define the builder first so that any validation of luci.builder arguments
    # (e.g. bucket) occurs before we try to use it
    ret = builders.builder(
        name = name,
        branch_selector = branch_selector,
        list_view = list_view,
        resultdb_bigquery_exports = merged_resultdb_bigquery_exports,
        resultdb_index_by_timestamp = library_settings.resultdb_index_by_timestamp,
        properties = properties,
        **kwargs
    )

    bucket = defaults.get_value_from_kwargs("bucket", kwargs)
    builder = "{}/{}".format(bucket, name)
    cq_groups = defaults.get_value("cq_group", cq_group)
    if cq_groups != None:
        default_disable_reuse_footers = _DEFAULT_DISABLE_REUSE_FOOTERS
        if not library_settings.add_default_disable_reuse_footers:
            default_disable_reuse_footers = None
        if type(cq_groups) != type([]):
            cq_groups = [cq_groups]
        if cq_settings != None:
            location_filters = cq_settings.location_filters
            if cq_settings.add_default_filters:
                location_filters = (location_filters or []) + default_location_filters(builder)
            disable_reuse_footers = cq_settings.disable_reuse_footers
            if cq_settings.disable_reuse:
                # disable_reuse and disable_reuse_footers canot be used
                # together, so set disable_reuse_footers to None
                disable_reuse_footers = None
            elif cq_settings.add_default_disable_reuse_footers:
                disable_reuse_footers = args.listify(
                    disable_reuse_footers,
                    default_disable_reuse_footers,
                )
            if not cq_settings.omit_from_luci_cv:
                kwargs = {}

                if not cq_settings.includable_only:
                    if cq_settings.custom_cq_run_modes:
                        kwargs["mode_allowlist"] = cq_settings.custom_cq_run_modes
                    elif library_settings.generate_default_cq_run_modes:
                        # These are the default if includable_only is False, but
                        # we list them here so we can add additional modes in a
                        # later generator.
                        kwargs["mode_allowlist"] = [
                            cq.MODE_DRY_RUN,
                            cq.MODE_FULL_RUN,
                        ]
                for cq_group in cq_groups:
                    luci.cq_tryjob_verifier(
                        builder = builder,
                        cq_group = cq_group,
                        disable_reuse = cq_settings.disable_reuse,
                        disable_reuse_footers = disable_reuse_footers,
                        experiment_percentage = cq_settings.experiment_percentage,
                        includable_only = cq_settings.includable_only,
                        location_filters = location_filters,
                        cancel_stale = cq_settings.cancel_stale,
                        equivalent_builder = cq_settings.equivalent_builder,
                        equivalent_builder_percentage = cq_settings.equivalent_builder_percentage,
                        equivalent_builder_whitelist = cq_settings.equivalent_builder_whitelist,
                        **kwargs
                    )
        else:
            kwargs = {}
            if default_disable_reuse_footers:
                # If someone adds a builder using CQ-Include-Trybots and it has
                # ci_only tests configured, then we would want it to get rerun
                # if the Include-Ci-Only-Tests footer gets changed
                kwargs["disable_reuse_footers"] = default_disable_reuse_footers
            for cq_group in cq_groups:
                # Allow CQ to trigger this builder if user opts in via CQ-Include-Trybots.
                luci.cq_tryjob_verifier(
                    builder = builder,
                    cq_group = cq_group,
                    includable_only = True,
                    **kwargs
                )

    return ret

def presubmit_builder(*, name, cq_settings = None, tryjob = None, **kwargs):
    """Define a presubmit builder.

    Presubmit builders are builders that run fast checks that don't require
    building. Their results aren't re-used because they tend to provide guards
    against generated files being out of date, so they MUST run quickly so that
    the submit after a CQ dry run doesn't take long.

    Args:
        name: The builder to define.
        cq_settings: An optional try_.cq_settings controlling when the builder is
            added to the CQ. If disable_reuse isn't set, it will be set to
            True. The add_default_filters value will be forced to False.
        tryjob: DEPRECATED An optional try_.job controlling when the builder is
            added to the CQ. If disable_reuse isn't set, it will be set to
            True. The add_default_filters value will be forced to False.
        **kwargs: Additional keyword args to forward to try_.builder.

    Returns:
        The lucicfg keyset for the builder, None if the builder wasn't defined
        (e.g. branch selector doesn't match current project's settings).
    """
    if cq_settings and tryjob:
        fail("presubmit_builder cannot be called with both cq_settings and tryjob. Use cq_settings.")
    if tryjob:
        cq_settings = tryjob

    if cq_settings:
        cq_settings_args = {a: getattr(cq_settings, a) for a in dir(cq_settings)}
        if cq_settings_args.get("disable_reuse") == None:
            cq_settings_args["disable_reuse"] = True
        cq_settings_args["add_default_filters"] = False
        cq_settings = try_.cq_settings(**cq_settings_args)
    return try_builder(name = name, cq_settings = cq_settings, **kwargs)

def _orchestrator_builder(
        *,
        name,
        compilator,
        use_orchestrator_pool = False,
        **kwargs):
    """Define an orchestrator builder.

    An orchestrator builder is part of a pair of try builders. The orchestrator
    triggers an associated compilator builder, which performs compilation and
    isolation on behalf of the orchestrator. The orchestrator extracts from the
    compilator the information necessary to trigger tests. This allows the
    orchestrator to run on a small machine and improves compilation times
    because the compilator will be compiling more often and can run on a larger
    machine.

    The properties set for the orchestrator will be copied to the compilator,
    with the exception of the $build/orchestrator property that is automatically
    added to the orchestrator.


    Args:
        name: The name of the orchestrator.
        compilator: A string identifying the associated compilator. Compilators
            can be defined using try_.compilator_builder.
        use_orchestrator_pool: Whether to use the bots in
            luci.chromium.try.orchestrator pool. This kwarg should be taken out
            once all CQ builders are migrated to be srcless (crbug/1287228)
        **kwargs: Additional kwargs to be forwarded to try_.builder.
            The following kwargs will have defaults applied if not set:
            * builderless: True on branches, False on main
            * cores: The orchestrator_cores module-level default.
            * executable: "recipe:chromium/orchestrator"
            * os: os.LINUX_DEFAULT
            * service_account: "chromium-orchestrator@chops-service-accounts.iam.gserviceaccount.com"
            * ssd: None

    Returns:
        The lucicfg keyset for the builder, None if the builder wasn't defined
        (e.g. branch selector doesn't match current project's settings).
    """
    builder_group = defaults.get_value_from_kwargs("builder_group", kwargs)
    if not builder_group:
        fail("builder_group must be specified")

    # TODO(crbug.com/40211151): Make this the default once all CQ builders are
    # migrated to be srcless
    if use_orchestrator_pool:
        kwargs.setdefault("pool", "luci.chromium.try.orchestrator")
        kwargs.setdefault("builderless", None)
    else:
        project_settings = _chromium_luci.project_settings()
        kwargs.setdefault("builderless", not project_settings.is_main)

    # Orchestrator builders that don't use a src checkout don't need a
    # builder cache.
    kwargs.setdefault("caches", [SOURCELESS_BUILDER_CACHE])

    kwargs.setdefault("cores", defaults.orchestrator_cores.get())
    kwargs.setdefault("executable", "recipe:chromium/orchestrator")

    kwargs.setdefault("os", os.LINUX_DEFAULT)
    kwargs.setdefault("service_account", "chromium-orchestrator@chops-service-accounts.iam.gserviceaccount.com")
    kwargs.setdefault("ssd", None)

    kwargs.setdefault("siso_remote_jobs", defaults.orchestrator_siso_remote_jobs.get())

    ret = try_.builder(name = name, **kwargs)
    if ret:
        bucket = defaults.get_value_from_kwargs("bucket", kwargs)

        register_orchestrator(bucket, name, builder_group, compilator)

    return ret

def _compilator_builder(*, name, **kwargs):
    """Define a compilator builder.

    An orchestrator builder is part of a pair of try builders. The compilator is
    triggered by an associated compilator builder, which performs compilation and
    isolation on behalf of the orchestrator. The orchestrator extracts from the
    compilator the information necessary to trigger tests. This allows the
    orchestrator to run on a small machine and improves compilation times
    because the compilator will be compiling more often and can run on a larger
    machine.

    The properties set for the orchestrator will be copied to the compilator,
    with the exception of the $build/orchestrator property that is automatically
    added to the orchestrator.

    Args:
        name: The name of the compilator.
        **kwargs: Additional kwargs to be forwarded to try_.builder. With the
            exception of builder_group, kwargs that would normally cause
            properties to be set will result in an error. Properties should
            instead be configured on the orchestrator. The following kwargs will
            have defaults applied if not set:
            * builderless: True on branches, False on main
            * cores: The compilator_cores module-level default.
            * executable: "recipe:chromium/compilator"
            * ssd: True

    Returns:
        The lucicfg keyset for the builder, None if the builder wasn't defined
        (e.g. branch selector doesn't match current project's settings).
    """
    builder_group = defaults.get_value_from_kwargs("builder_group", kwargs)
    if not builder_group:
        fail("builder_group must be specified")

    kwargs.setdefault("builderless", not _chromium_luci.project_settings().is_main)
    kwargs.setdefault("cores", defaults.compilator_cores.get())
    kwargs.setdefault("executable", "recipe:chromium/compilator")
    kwargs.setdefault("ssd", True)

    kwargs["siso_project"] = None
    kwargs["siso_enabled"] = False
    kwargs["test_presentation"] = resultdb.test_presentation()

    ret = try_.builder(name = name, **kwargs)
    if ret:
        bucket = defaults.get_value_from_kwargs("bucket", kwargs)

        register_compilator(bucket, name)

    return ret

try_ = struct(
    # Module-level defaults for try functions
    defaults = defaults,

    # Functions for declaring try builders
    builder = try_builder,
    presubmit_builder = presubmit_builder,
    job = tryjob,  # DEPRECATED in favor of cq_settings
    cq_settings = cq_settings,
    orchestrator_builder = _orchestrator_builder,
    compilator_builder = _compilator_builder,

    # CONSTANTS
    MEGA_CQ_DRY_RUN_NAME = "CQ_MODE_MEGA_DRY_RUN",
    MEGA_CQ_FULL_RUN_NAME = "CQ_MODE_MEGA_FULL_RUN",
)
