#!/usr/bin/env lucicfg
# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Check that the other starlark files can be loaded.

The starlark files were migrated from the //infra/config lib directory in
chromium/src. They rely on the presence of a project.star at the root of the
package that has a settings struct that provides details for the containing
project. Such a file doesn't exist for the files in this repo because the
package is a library package intended to be used by multiple projects. Executing
this file ensures that any starlark files that it loads can be successfully
loaded. As the files are updated to remove the dependency on project.star, their
load can be uncommented here to ensure they remain loadable.
"""

load("//args.star", "args")  # @unused

# Loads project.star, builder_config.star, orchestrator.star
# load("//bootstrap.star", "bootstrap")  # @unused

load("//branches.star", "branches")  # @unused

# Loads project.star, sheriff_rotations.star
# Generator fails because there is no cr-buildbucket.cfg
# load("//builder_config.star", "builder_config")  # @unused

# Loads project.star
# load("//builder_health_indicators.star", "builder_health_indicators")  # @unused

# Loads project.star, bootstrap.star, builder_config.star,
# builder_health_indicators.star, recipe_experiments.star,
# sheriff_rotations.star
# load("//builders.star", "builders")  # @unused

load("//chrome_settings.star", "chrome_settings")  # @unused

# Loads project.star, builder_config.star, builders.star
# load("//ci.star", "ci")  # @unused

load("//consoles.star", "consoles")  # @unused
load("//dimensions.star", "dimensions")  # @unused
load("//enums.star", "enums")  # @unused
load("//gn_args.star", "gn_args")  # @unused
load("//headers.star", "headers")  # @unused
load("//html.star", "linkify")  # @unused
load("//nodes.star", "nodes")  # @unused
load("//notifiers.star", "notifiers")  # @unused

# Loads builder_config.star
# load("//orchestrator.star", "orchestrator")  # @unused

# Loads project.star, builders.star
# load("//polymorphic.star", "polymorphic")  # @unused

# Generator fails because there is no cr-buildbucket.cfg
# load("//recipe_experiments.star", "register_recipe_experiments")  # @unused

# Loads project.star
# load("//sheriff_rotations.star", "sheriff_rotations")  # @unused

load("//structs.star", "structs")  # @unused
load("//swarming.star", "swarming")  # @unused

# Generates output files
# load("//targets.star", "targets")  # @unused

# Loads project.star, builders.star, orchestrator.star
# load("//try.star", "try_")  # @unused

load("//xcode.star", "xcode")  # @unused
