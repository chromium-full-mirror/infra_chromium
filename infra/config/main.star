#!/usr/bin/env lucicfg
# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

lucicfg.config(
    fail_on_warnings = True,
    lint_checks = ["all"],
)

luci.project(
    name = "chromium-infra",
    config_dir = "luci",
    acls = [
        acl.entry(
            roles = [
                acl.PROJECT_CONFIGS_READER,
            ],
            groups = "all",
        ),
    ],
)

luci.cq(
    submit_max_burst = 2,
    submit_burst_delay = time.minute,
    honor_gerrit_linked_accounts = True,
)

luci.cq_group(
    name = "cq",
    watch = cq.refset(
        repo = "https://chromium.googlesource.com/infra/chromium",
    ),
    # keep this mostly in sync with chromium/src's CQ's ACLs
    acls = [
        acl.entry(
            acl.CQ_COMMITTER,
            groups = "project-chromium-submit-access",
        ),
        acl.entry(
            acl.CQ_DRY_RUNNER,
            groups = "project-chromium-tryjob-access",
        ),
        acl.entry(
            acl.CQ_NEW_PATCHSET_RUN_TRIGGERER,
            groups = "project-chromium-tryjob-access",
        ),
    ],
)
