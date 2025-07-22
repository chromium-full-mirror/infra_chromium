# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

PRESUBMIT_VERSION = '2.0.0'


# _check.star doesn't generate any output, but running it will ensure that other
# starlark files can be loaded and are lint-clean
def CheckLucicfgGenOutput(input_api, output_api):
    return input_api.RunTests(
        input_api.canned_checks.CheckLucicfgGenOutput(input_api, output_api,
                                                      '_check.star'))
