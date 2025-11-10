# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Package declaration for chromium-luci library."""

pkg.declare(
    name = "@chromium-luci",
    lucicfg = "1.46.1",
)

# _check.star is just a top-level script that loads all of the starlark files
# within the directory to ensure that they can be successfully loaded
pkg.entrypoint("_check.star")

pkg.options.lint_checks([
    "all",
    # Let dicts be not sorted, we can use go/keep-sorted for dicts that we want
    # sorted
    "-unsorted-dict-items",
])
