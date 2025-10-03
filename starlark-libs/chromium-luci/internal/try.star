# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Internal library for defining try builders."""

load("./chromium_luci.star", _chromium_luci = "chromium_luci")

def default_location_filters(builder_name = None):
    """Get the default location filters for a builder.

    Args:
        builder_name: The qualified-name of the builder to get the location
            filters for. May be a bucket-qualified name (e.g. try/linux-rel) or
            a project-qualified name (e.g. chromium/try/linux-rel). If
            specified, the builder's config files at
            //infra/config/generated/builders/ are added to the default
            include-filters returned.

    Returns:
        A list of cq.location_filter objects to use for the builder.
    """

    def location_filter(*, path_regexp, exclude = False):
        return cq.location_filter(
            gerrit_host_regexp = ".*",
            gerrit_project_regexp = ".*",
            path_regexp = path_regexp,
            exclude = exclude,
        )

    filters = [
        # Contains configuration files that aren't active until after committed
        location_filter(path_regexp = "infra/config/.+", exclude = True),
    ]
    for r in _chromium_luci.try_settings().additional_default_exclude_path_regexps:
        filters.append(location_filter(path_regexp = r, exclude = True))

    if builder_name:
        pieces = builder_name.split("/")
        if len(pieces) == 2:
            bucket, builder = pieces
        elif len(pieces) == 3:
            _, bucket, builder = pieces
        else:
            fail("builder_name must be a qualified builder name, got {}".format(builder_name))
        filters.append(
            # Contains builder-specific files that can be consumed by the builder
            # pre-submit
            location_filter(path_regexp = "infra/config/generated/builders/{}/{}/.+".format(bucket, builder)),
        )

    return filters

def location_filters_without_defaults(tryjob_builder_proto):
    default_filters = default_location_filters(tryjob_builder_proto.name)
    return [f for f in tryjob_builder_proto.location_filters if cq.location_filter(
        gerrit_host_regexp = f.gerrit_host_regexp,
        gerrit_project_regexp = f.gerrit_project_regexp,
        path_regexp = f.path_regexp,
        exclude = f.exclude,
    ) not in default_filters]
