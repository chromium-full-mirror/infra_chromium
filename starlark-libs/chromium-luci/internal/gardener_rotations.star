# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Internal library for defining gardener rotations."""

load("//branches.star", _branches = "branches")

def _rotation(name, console_name, tree_closer_console, *, branch_selector = _branches.selector.MAIN):
    if not name:
        fail("Rotations must be created with a name")

    def get():
        val = struct(
            name = name,
            console_name = console_name,
            tree_closer_console = tree_closer_console,
            branch_selector = branch_selector,
        )
        return _branches.value(
            branch_selector = branch_selector,
            value = val,
        )

    return struct(get = get)

gardener_rotations = struct(
    rotation = _rotation,
)
