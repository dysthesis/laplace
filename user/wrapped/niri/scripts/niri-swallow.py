#!/usr/bin/env python3
"""Move tiled child windows into their terminal's Niri column."""

import json
import os
import socket
import sys

SOCKET = os.environ["NIRI_SOCKET"]
TERMINAL_APP_ID = sys.argv[1]


def connect():
    sock = socket.socket(socket.AF_UNIX)
    sock.settimeout(2)
    sock.connect(SOCKET)
    return sock


def request(message):
    with connect() as sock:
        sock.sendall((json.dumps(message) + "\n").encode())
        with sock.makefile() as stream:
            reply = json.loads(stream.readline())
    if "Ok" not in reply:
        raise RuntimeError(reply.get("Err", reply))
    return reply["Ok"]


def action(name, **kwargs):
    request({"Action": {name: kwargs}})


def windows():
    return {w["id"]: w for w in request("Windows")["Windows"]}


def column(window):
    return window["layout"]["pos_in_scrolling_layout"][0]


def ancestor_terminal(pid, all_windows, child_id):
    owners = {}
    for w in all_windows.values():
        if w["id"] != child_id and w["pid"]:
            owners.setdefault(w["pid"], []).append(w)

    seen = set()
    while pid and pid > 1 and pid not in seen:
        seen.add(pid)
        matches = owners.get(pid, [])
        if matches:
            return matches[0]["id"] if len(matches) == 1 and matches[0]["app_id"] == TERMINAL_APP_ID else None
        try:
            # The comm field can contain spaces or parentheses.
            with open(f"/proc/{pid}/stat") as proc:
                stat = proc.read()
            pid = int(stat.rsplit(") ", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    return None


def swallow(child_id):
    current = windows()
    child = current.get(child_id)
    if not child or not child["pid"] or child["is_floating"] or not child["layout"]["pos_in_scrolling_layout"]:
        return

    parent_id = ancestor_terminal(child["pid"], current, child_id)
    parent = current.get(parent_id)
    if not parent or parent["is_floating"] or not parent["layout"]["pos_in_scrolling_layout"]:
        return
    if not parent["workspace_id"]:
        return
    if not any(w["is_focused"] and w["id"] in (parent_id, child_id) for w in current.values()):
        return  # Do not take focus from an unrelated window.

    if parent["workspace_id"] != child["workspace_id"]:
        if not child["is_focused"]:
            return
        action("MoveWindowToWorkspace", window_id=child_id,
               reference={"Id": parent["workspace_id"]}, focus=True)
        current = windows()
        parent, child = current.get(parent_id), current.get(child_id)
        if not parent or not child or parent["workspace_id"] != child["workspace_id"]:
            return
        if child["is_floating"] or not child["layout"]["pos_in_scrolling_layout"]:
            return

    parent_col, child_col = column(parent), column(child)
    if parent_col != child_col:
        # Do not move columns that contain more than one window.
        if sum(w["workspace_id"] == child["workspace_id"]
               and not w["is_floating"] and column(w) == child_col
               for w in current.values()) != 1:
            return

        direction = "Left" if child_col > parent_col else "Right"
        target = parent_col + (1 if child_col > parent_col else -1)
        if child_col != target:
            action("FocusWindow", id=child_id)
            action("MoveColumnToIndex", index=target)

        # Read the updated positions after the column move.
        current = windows()
        parent, child = current.get(parent_id), current.get(child_id)
        if not parent or not child or parent["workspace_id"] != child["workspace_id"]:
            return
        if abs(column(parent) - column(child)) != 1:
            return
        if (column(child) > column(parent)) != (direction == "Left"):
            return
        action(f"ConsumeOrExpelWindow{direction}", id=child_id)

    current = windows()
    parent, child = current.get(parent_id), current.get(child_id)
    if not parent or not child or parent["workspace_id"] != child["workspace_id"]:
        return
    if column(parent) != column(child):
        return
    action("FocusWindow", id=parent_id)
    action("SetColumnDisplay", display="Tabbed")
    action("FocusWindow", id=child_id)


def main():
    with connect() as sock:
        sock.settimeout(None)
        sock.sendall(b'"EventStream"\n')
        with sock.makefile() as stream:
            if json.loads(stream.readline()) != {"Ok": "Handled"}:
                raise RuntimeError("Niri rejected EventStream")
            known = None
            pending = set()
            for line in stream:
                event = json.loads(line)
                if "WindowsChanged" in event:
                    items = event["WindowsChanged"]["windows"]
                    ids = {w["id"] for w in items}
                    if known is not None:
                        pending.update(ids - known)
                    known = ids
                    pending.intersection_update(known)
                    candidates = (w for w in items if w["id"] in pending)
                elif "WindowOpenedOrChanged" in event and known is not None:
                    item = event["WindowOpenedOrChanged"]["window"]
                    if item["id"] not in known:
                        known.add(item["id"])
                        pending.add(item["id"])
                    candidates = (item,)
                elif "WindowClosed" in event and known is not None:
                    closed = event["WindowClosed"]["id"]
                    known.discard(closed)
                    pending.discard(closed)
                    continue
                else:
                    continue

                for item in candidates:
                    if (item["id"] in pending and item["pid"] is not None
                            and (item["is_floating"] or item["layout"]["pos_in_scrolling_layout"])):
                        pending.remove(item["id"])
                        try:
                            swallow(item["id"])
                        except (OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
                            print(f"niri-swallow: {exc}", file=sys.stderr)
    raise RuntimeError("Niri event stream closed")


if __name__ == "__main__":
    main()
