"""Reconcile only Preferences/WebUI\\ServerDomains in the mutable profile."""

import os
from pathlib import Path
import stat
import sys
import tempfile


path = Path(sys.argv[1])
domain = sys.argv[2].encode()
original = path.read_bytes()
lines = original.splitlines(keepends=True)
key = b"WebUI\\ServerDomains"
section = None
preferences_start = None
found = False
newline = b"\r\n" if b"\r\n" in original else b"\n"

for index, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith(b"[") and stripped.endswith(b"]"):
        section = stripped[1:-1]
        if section == b"Preferences":
            preferences_start = index
    elif section == b"Preferences" and line.partition(b"=")[0].strip() == key:
        ending = b"\r\n" if line.endswith(b"\r\n") else b"\n" if line.endswith(b"\n") else b""
        lines[index] = line.partition(b"=")[0] + b"=" + domain + ending
        found = True

if not found:
    entry = key + b"=" + domain + newline
    if preferences_start is None:
        if lines and not lines[-1].endswith(b"\n"):
            lines[-1] += newline
        lines.extend([b"[Preferences]" + newline, entry])
    else:
        if not lines[preferences_start].endswith(b"\n"):
            lines[preferences_start] += newline
        lines.insert(preferences_start + 1, entry)

updated = b"".join(lines)
if updated != original:
    metadata = path.stat()
    # A rename in the same directory publishes the complete profile atomically.
    # Keep its owner and mode to protect the generated password.
    fd, temporary = tempfile.mkstemp(prefix=".qbittorrent-domain-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            temporary_metadata = os.fstat(output.fileno())
            if (temporary_metadata.st_uid, temporary_metadata.st_gid) != (metadata.st_uid, metadata.st_gid):
                os.fchown(output.fileno(), metadata.st_uid, metadata.st_gid)
            os.fchmod(output.fileno(), stat.S_IMODE(metadata.st_mode))
            output.write(updated)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
