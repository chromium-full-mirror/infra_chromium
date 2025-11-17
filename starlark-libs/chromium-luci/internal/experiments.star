# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library providing an experiments facility.

Experiments provide a way to evolve the behavior of the library code with a
lower burden that introducing additional configurable values.
"""

# **NOTE**
#
# Experiments would be part of the project settings directly, but adding an
# experiment check in targets-internal/common.star resulted in a load cycle:
# //internal/chromium_luci.star -> //targets-internal/pyl-generators.star ->
#     //targets-internal/common.star -> //internal/chromium_luci.star
#
# Making it a separate file with limited loading means that it should be safe to
# add experiment checks to any code except settings.star and nodes.star, which
# should be fine since those are implementation details of the library.

load("./settings.star", _settings = "settings")

_SETTINGS = _settings.settings(
    "experiments-settings",
    required_configure = "chromium_luci.configure_project",
)

_KNOWN_EXPERIMENTS = set([
    # go/keep-sorted start
    "builder_config.targets_spec_directory_relative_to_source_dir",
    "targets.module_name_without_slash",
    "targets.module_scheme_generator",
    "targets.module_scheme_junit_tests",
    "targets.module_scheme_regex",
    "targets.module_scheme_script_tests",
    "try.enforce_cq_settings_exclusivity",
    # go/keep-sorted end
])

def _enable(experiments):
    """Enable experiments for the project.

    Args:
        experiments: A list of strings enabling behavior changes in the
            libraries. Unknown experiments will be ignored and result in a
            message being printed.
    """
    enabled_experiments = []
    for e in experiments:
        if e in _KNOWN_EXPERIMENTS:
            enabled_experiments.append(e)
        else:
            print('Obsolete or unknown experiment: "{}"'.format(e))
    _SETTINGS.set(enabled_experiments = set(enabled_experiments))

def _is_enabled(experiment):
    """Check if an experiment is enabled.

    Returns:
        True if the experiment was passed to experiments.enable and it is one of
        the known experiment values. Otherwise, false.
    """
    return experiment in _SETTINGS.get().enabled_experiments

experiments = struct(
    enable = _enable,
    is_enabled = _is_enabled,
)
