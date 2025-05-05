# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

PRESUBMIT_VERSION = '2.0.0'

def CheckLucicfgGenOutputMain(input_api, output_api):
  return input_api.RunTests(input_api.canned_checks.CheckLucicfgGenOutput(
      input_api, output_api, 'main.star'))

def CheckChangedLUCIConfigs(input_api, output_api):
  return input_api.canned_checks.CheckChangedLUCIConfigs(
      input_api, output_api)
