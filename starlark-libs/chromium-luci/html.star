# Copyright 2024 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""A library for working with html."""

load("//internal/chromium_luci.star", _chromium_luci = "chromium_luci")

def linkify(url, text):
    """Returns a <a> html hyperlink."""
    return "<a href=\"{}\">{}</a>".format(url, text)

def builder_url(bucket, builder, project = None):
    """Get a milo URL for a builder.

    Args:
        bucket: The bucket of the builder.
        builder: The builder's name.
        project: The project of the builder. If not provided, then the name of
            the current project will be used.
    """
    project = project or _chromium_luci.project_settings().name
    url = "https://ci.chromium.org/p/%s/builders/%s/%s" % (
        project,
        bucket,
        builder,
    )
    return url

def linkify_builder(bucket, builder, project = None):
    """Returns an HTML link to a builder compatible with Milo-descriptions."""
    return linkify(builder_url(bucket, builder, project), builder)
