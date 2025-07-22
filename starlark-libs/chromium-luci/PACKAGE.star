# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Package declaration for chromium-luci library."""

pkg.declare(
    name = "@chromium-luci",
    lucicfg = "1.45.0",
)

pkg.options.lint_checks([
    "all",
    # Let dicts be not sorted, we can use go/keep-sorted for dicts that we want
    # sorted
    "-unsorted-dict-items",
])
