# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library providing functions for configuring libraries.

`chromium_luci.configure_project` should be called by all projects to provide
all libraries access to the project name and whether the project is a main
project or what platforms the project is configured for.
"""

load("//internal/chromium_luci.star", _chromium_luci = "chromium_luci")

chromium_luci = struct(
    configure_project = _chromium_luci.configure_project,
    configure_per_builder_outputs = _chromium_luci.configure_per_builder_outputs,

    # library-specific configuration
    configure_builder_config = _chromium_luci.configure_builder_config,
    configure_builder_health_indicators = _chromium_luci.configure_builder_health_indicators,
    configure_gardener_rotations = _chromium_luci.configure_gardener_rotations,
    configure_gn_args = _chromium_luci.configure_gn_args,
    configure_targets = _chromium_luci.configure_targets,
)
