# Copyright 2025 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Internal library for codesearch queries."""

def _url_quote(s):
    s = s.replace("%", "%25")
    s = s.replace("+", "%2B")
    s = s.replace(" ", "%20")
    s = s.replace('"', "%22")
    s = s.replace("\\", "%5C")
    return s

def _codesearch_query(url, *atoms):
    query = " ".join(atoms)
    return "{}/search?q={}".format(url, _url_quote(query))

def _public_query(*atoms):
    return _codesearch_query("https://cs.chromium.org", *atoms)

def _internal_query(*atoms):
    return _codesearch_query("https://source.corp.google.com", *atoms)

codesearch = struct(
    public_query = _public_query,
    internal_query = _internal_query,
)
