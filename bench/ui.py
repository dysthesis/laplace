#!/usr/bin/env python3
import sys

try:
    from rich.console import Console
    _con = Console(stderr=True)
    _RICH = True
except Exception:
    _RICH = False


def rule(text):
    if _RICH:
        _con.rule(f"[bold cyan]{text}")
    else:
        print(f"\n=== {text} ===", file=sys.stderr)


def panel(title, body):
    if _RICH:
        from rich.panel import Panel

        _con.print(Panel(body, title=f"[bold]{title}", border_style="cyan",
                         expand=False))
    else:
        print(f"\n[{title}]\n{body}", file=sys.stderr)


def kv(title, pairs):
    items = []
    for p in pairs:
        k, _, v = p.partition("=")
        items.append((k, v))
    if _RICH:
        from rich import box
        from rich.table import Table

        t = Table(box=box.MINIMAL, show_header=False, title=f"[bold]{title}",
                  title_style="bold cyan", title_justify="left")
        t.add_column(style="dim")
        t.add_column(style="white")
        for k, v in items:
            t.add_row(k, v)
        _con.print(t)
    else:
        print(f"\n[{title}]", file=sys.stderr)
        for k, v in items:
            print(f"  {k}: {v}", file=sys.stderr)


def main():
    if len(sys.argv) < 2:
        sys.exit(0)
    cmd = sys.argv[1]
    if cmd == "rule":
        rule(sys.argv[2] if len(sys.argv) > 2 else "")
    elif cmd == "panel":
        panel(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
    elif cmd == "kv":
        kv(sys.argv[2], sys.argv[3:])
    else:
        print(" ".join(sys.argv[2:]), file=sys.stderr)


if __name__ == "__main__":
    main()
