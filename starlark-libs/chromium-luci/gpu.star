# Copyright 2026 The Chromium Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Library for defining GPU builders.

This is considered non-project-specific since this is applicable to multiple
GPU-related projects (Chromium, ANGLE, Dawn, etc.).
"""

load("./builders.star", "builders", "cpu", "os")
load("./ci.star", "ci")
load("./try.star", "try_")

def _apply_gpu_linux_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU Linux builders % thin testers."""
    kwargs.setdefault("cores", 8)
    kwargs.setdefault("cpu", "x86-64")
    kwargs.setdefault("free_space", None)
    kwargs.setdefault("os", os.LINUX_DEFAULT)
    kwargs.setdefault("ssd", None)
    return kwargs

def _apply_gpu_mac_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU Mac builders."""
    kwargs.setdefault("cores", None)
    kwargs.setdefault("cpu", cpu.ARM64)
    kwargs.setdefault("free_space", None)
    kwargs.setdefault("os", os.MAC_ANY)
    kwargs.setdefault("ssd", None)
    return kwargs

def _apply_gpu_win_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU Windows builders."""
    kwargs.setdefault("cores", 8)
    kwargs.setdefault("free_space", None)
    kwargs.setdefault("os", os.WINDOWS_ANY)
    kwargs.setdefault("ssd", builders.with_expiration(True, expiration = 5 * time.minute))
    return kwargs

def _apply_gpu_ci_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU CI builders % thin testers."""
    kwargs.setdefault("builderless", True)
    kwargs.setdefault("pool", gpu.ci.POOL)
    return kwargs

def _gpu_ci_linux_builder(*args, **kwargs):
    """Defines a GPU-related Linux CI builder."""
    kwargs = _apply_gpu_linux_builder_defaults(kwargs)
    kwargs = _apply_gpu_ci_builder_defaults(kwargs)
    return ci.builder(*args, **kwargs)

def _gpu_ci_mac_builder(*args, **kwargs):
    """Defines a GPU-related Mac CI builder."""
    kwargs = _apply_gpu_mac_builder_defaults(kwargs)
    kwargs = _apply_gpu_ci_builder_defaults(kwargs)
    return ci.builder(*args, **kwargs)

def _gpu_ci_windows_builder(*args, **kwargs):
    """Defines a GPU-related Windows CI builder."""
    kwargs = _apply_gpu_win_builder_defaults(kwargs)
    kwargs = _apply_gpu_ci_builder_defaults(kwargs)
    return ci.builder(*args, **kwargs)

def _apply_gpu_try_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU try builders."""
    kwargs.setdefault("builderless", True)
    kwargs.setdefault("pool", gpu.try_.POOL)
    return kwargs

def _apply_gpu_manual_try_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU manual-only try builders."""
    kwargs = _apply_gpu_try_builder_defaults(kwargs)
    kwargs.setdefault("max_concurrent_builds", 1)
    return kwargs

def _gpu_try_manual_linux_builder(*args, **kwargs):
    """Defines a GPU-related Linux manual-only trybot."""
    kwargs = _apply_gpu_manual_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_linux_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _gpu_try_manual_mac_builder(*args, **kwargs):
    """Defines a GPU-related Mac manual-only trybot."""
    kwargs = _apply_gpu_manual_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_mac_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _gpu_try_manual_win_builder(*args, **kwargs):
    """Defines a GPU-related Windows manual-only trybot."""
    kwargs = _apply_gpu_manual_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_win_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _apply_gpu_rate_limited_try_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU rate limited trybots.

    Rate limited builders are those that are used more frequently than normal
    manual-only trybots, but are still not automatically added to CLs like
    optional trybots are.
    """
    if not try_.defaults.get_value_from_kwargs("max_concurrent_builds", kwargs):
        fail("max_concurrent_builds not set on a builder that expects it.")
    kwargs = _apply_gpu_try_builder_defaults(kwargs)
    return kwargs

def _gpu_try_rate_limited_linux_builder(*args, **kwargs):
    """Defines a GPU-related Linux rate limited trybot."""
    kwargs = _apply_gpu_rate_limited_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_linux_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _gpu_try_rate_limited_mac_builder(*args, **kwargs):
    """Defines a GPU-related Mac rate limited trybot."""
    kwargs = _apply_gpu_rate_limited_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_mac_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _gpu_try_rate_limited_win_builder(*args, **kwargs):
    """Defines a GPU-related Windows rate limited trybot."""
    kwargs = _apply_gpu_rate_limited_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_win_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _apply_gpu_optional_try_builder_defaults(kwargs):
    """Applies defaults applicable to all GPU optional trybots."""
    if not kwargs.get("cq_settings"):
        fail("cq_settings must be set for an optional builder to set location filters.")
    kwargs = _apply_gpu_rate_limited_try_builder_defaults(kwargs)
    kwargs.setdefault("execution_timeout", 6 * time.hour)
    return kwargs

def _gpu_try_optional_linux_builder(*args, **kwargs):
    """Defines a GPU-related Linux optional trybot."""
    kwargs = _apply_gpu_optional_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_linux_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _gpu_try_optional_mac_builder(*args, **kwargs):
    """Defines a GPU-related mac optional trybot."""
    kwargs = _apply_gpu_optional_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_mac_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _gpu_try_optional_win_builder(*args, **kwargs):
    """Defines a GPU-related Windows optional trybot."""
    kwargs = _apply_gpu_optional_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_win_builder_defaults(kwargs)
    return try_.builder(*args, **kwargs)

def _gpu_try_presubmit_linux_builder(*args, **kwargs):
    """Defines a GPU-related Linux presubmit trybot.

    This is effectively a rate-limited builder that uses try_.presubmit_builder
    instead of try_.builder.
    """
    kwargs = _apply_gpu_rate_limited_try_builder_defaults(kwargs)
    kwargs = _apply_gpu_linux_builder_defaults(kwargs)
    return try_.presubmit_builder(*args, **kwargs)

gpu = struct(
    ci = struct(
        POOL = "luci.chromium.gpu.ci",
        linux_builder = _gpu_ci_linux_builder,
        mac_builder = _gpu_ci_mac_builder,
        windows_builder = _gpu_ci_windows_builder,
    ),
    try_ = struct(
        POOL = "luci.chromium.gpu.try",
        linux_manual_builder = _gpu_try_manual_linux_builder,
        linux_optional_builder = _gpu_try_optional_linux_builder,
        linux_presubmit_builder = _gpu_try_presubmit_linux_builder,
        linux_rate_limited_builder = _gpu_try_rate_limited_linux_builder,
        mac_manual_builder = _gpu_try_manual_mac_builder,
        mac_optional_builder = _gpu_try_optional_mac_builder,
        mac_rate_limited_builder = _gpu_try_rate_limited_mac_builder,
        win_manual_builder = _gpu_try_manual_win_builder,
        win_optional_builder = _gpu_try_optional_win_builder,
        win_rate_limited_builder = _gpu_try_rate_limited_win_builder,
    ),
)
