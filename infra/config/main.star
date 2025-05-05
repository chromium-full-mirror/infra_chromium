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
    buildbucket = "cr-buildbucket.appspot.com",
    logdog = "luci-logdog.appspot.com",
    milo = "luci-milo.appspot.com",
    swarming = "chromium-swarm.appspot.com",
    acls = [
        acl.entry(
            roles = [
                acl.PROJECT_CONFIGS_READER,
            ],
            groups = "all",
        ),
    ],
    bindings = [
        luci.binding(
            roles = "role/configs.validator",
            users = "chromium-try-builder@chops-service-accounts.iam.gserviceaccount.com",
        ),
    ]
)

luci.milo(
    logo = "https://storage.googleapis.com/chrome-infra-public/logo/chromium.svg",
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

luci.logdog(
    gs_bucket = "chromium-luci-logdog",
)

luci.bucket(
    name = "try",
    bindings = [
        luci.binding(
            roles = "role/buildbucket.reader",
            groups = "all",
        ),
        luci.binding(
            roles = "role/buildbucket.triggerer",
            groups = "project-chromium-tryjob-access",
        ),
    ],
)

# TODO: crbug.com/407065680 - Once the starlark libs in chromium/src's
# infra/config/lib directory are migrated here, take advantage of them to
# provide consistency with chromium builder declarations
luci.builder(
    name = "linux-presubmit",
    bucket = "try",
    executable = luci.recipe(
        name = "presubmit",
        cipd_package = "infra/recipe_bundles/chromium.googlesource.com/chromium/tools/build",
    ),
    service_account = "chromium-try-builder@chops-service-accounts.iam.gserviceaccount.com",
    dimensions = dict(
        builderless = "1",
        cores = "8",
        cpu = "x86-64",
        free_space = "standard",
        os = "Ubuntu-22.04",
        pool = "luci.chromium.try",
        ssd = "0",
    ),
)
