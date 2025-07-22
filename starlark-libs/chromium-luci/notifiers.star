# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""A library providing utilities for defining notifiers."""

load("//branches.star", "branches")

def _tree_closer_branch():
    return branches.matches(branches.selector.MAIN)

notifiers = struct(
    tree_closer_branch = _tree_closer_branch,
)
