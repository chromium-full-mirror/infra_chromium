# Copyright 2024 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Constants for xcode versions used by builders."""

def _enum(platform, version):
    return struct(
        version = version,
        cache = swarming.cache(
            name = "xcode_{}_{}".format(platform, version),
            path = "xcode_{}_{}.app".format(platform, version),
        ),
    )

xcode = struct(
    for_ios = lambda version: _enum("ios", version),
    for_mac = lambda version: _enum("mac", version),
)
