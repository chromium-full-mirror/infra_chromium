# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

USE_PYTHON3 = True
PRESUBMIT_VERSION = '2.0.0'


def CheckPanProjectChecks(input_api, output_api):
    return input_api.canned_checks.PanProjectChecks(
        input_api,
        output_api,
        owners_check=False,
    )


def CheckPatchFormatted(input_api, output_api):
    return input_api.canned_checks.CheckPatchFormatted(
        input_api,
        output_api,
        result_factory=output_api.PresubmitError,
    )
