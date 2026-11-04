#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import random
import statistics as st
import sys

random.seed(0xCAFE)  # Keep confidence intervals repeatable for the same samples.

METRIC_ORDER = [
    "first_prompt_lag_ms",
    "first_command_lag_ms",
    "command_lag_ms",
    "input_lag_ms",
    "input_lag_longbuf_ms",
    "exit_time_ms",
]


def percentile(xs, q):
    if not xs:
        return float("nan")
    s = sorted(xs)
    if len(s) == 1:
        return s[0]
    idx = q / 100.0 * (len(s) - 1)
    lo = math.floor(idx)
    hi = math.ceil(idx)
    if lo == hi:
        return s[lo]
    return s[lo] + (s[hi] - s[lo]) * (idx - lo)


def mad(xs):
    """Return the median absolute deviation, scaled for the standard deviation."""
    if len(xs) < 2:
        return 0.0
    med = st.median(xs)
    return 1.4826 * st.median([abs(x - med) for x in xs])


def bootstrap_median_ci(xs, iters=10000, alpha=0.05):
    if len(xs) < 2:
        m = xs[0] if xs else float("nan")
        return (m, m)
    n = len(xs)
    meds = []
    for _ in range(iters):
        sample = [xs[random.randrange(n)] for _ in range(n)]
        meds.append(st.median(sample))
    meds.sort()
    lo = percentile(meds, 100 * alpha / 2)
    hi = percentile(meds, 100 * (1 - alpha / 2))
    return (lo, hi)


def summarize_metric(xs):
    xs = [x for x in xs if x is not None]
    if not xs:
        return None
    lo, hi = bootstrap_median_ci(xs)
    return {
        "n": len(xs),
        "median": st.median(xs),
        "ci95_lo": lo,
        "ci95_hi": hi,
        "mad": mad(xs),
        "mean": st.fmean(xs),
        "p90": percentile(xs, 90),
        "p99": percentile(xs, 99),
        "min": min(xs),
        "max": max(xs),
    }


def mann_whitney_u(a, b):
    """Return (U, p) with a tie-corrected, two-sided normal approximation.

    Small samples give less accurate results.
    """
    na, nb = len(a), len(b)
    if na == 0 or nb == 0:
        return (float("nan"), float("nan"))
    combined = [(v, 0) for v in a] + [(v, 1) for v in b]
    combined.sort(key=lambda t: t[0])
    ranks = [0.0] * len(combined)
    i = 0
    while i < len(combined):
        j = i
        while j + 1 < len(combined) and combined[j + 1][0] == combined[i][0]:
            j += 1
        avg = (i + j) / 2.0 + 1.0
        for k in range(i, j + 1):
            ranks[k] = avg
        i = j + 1
    ra = sum(r for r, (_, g) in zip(ranks, combined) if g == 0)
    ua = ra - na * (na + 1) / 2.0
    ub = na * nb - ua
    u = min(ua, ub)
    mu = na * nb / 2.0
    n = na + nb
    tie = 0.0
    i = 0
    while i < len(combined):
        j = i
        while j + 1 < len(combined) and combined[j + 1][0] == combined[i][0]:
            j += 1
        t = j - i + 1
        tie += t**3 - t
        i = j + 1
    sigma = math.sqrt(
        na * nb / 12.0 * ((n + 1) - tie / (n * (n - 1)))
    ) if n > 1 else 0.0
    if sigma == 0:
        return (u, float("nan"))
    z = (u - mu + 0.5 * (1 if u < mu else -1)) / sigma  # continuity-corrected
    p = 2.0 * (1.0 - 0.5 * (1.0 + math.erf(abs(z) / math.sqrt(2))))
    return (u, max(0.0, min(1.0, p)))


def load(path):
    with open(path) as f:
        return json.load(f)


def fmt(x, w=8, p=2):
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return " " * (w - 1) + "-"
    return f"{x:{w}.{p}f}"


def cmd_summarize(paths, as_json):
    blobs = [load(p) for p in paths]
    if as_json:
        out = []
        for path, blob in zip(paths, blobs):
            row = {"file": path, "label": blob.get("label", ""),
                   "metrics": {}}
            for m in METRIC_ORDER:
                s = summarize_metric(blob.get("samples", {}).get(m, []))
                if s:
                    row["metrics"][m] = s
            out.append(row)
        json.dump(out, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    for path, blob in zip(paths, blobs):
        label = blob.get("label") or path
        sub = f"{blob.get('mode','')}/{blob.get('spawn_mode','')}"
        print(f"\n== {label}  ({sub})")
        print(f"{'metric':22} {'n':>4} {'median':>9} {'95% CI':>20} "
              f"{'MAD':>8} {'p90':>9} {'p99':>9}")
        for m in METRIC_ORDER:
            s = summarize_metric(blob.get("samples", {}).get(m, []))
            if not s:
                continue
            ci = f"[{fmt(s['ci95_lo'],0)},{fmt(s['ci95_hi'],0)}]"
            print(f"{m:22} {s['n']:>4} {fmt(s['median'],9)} {ci:>20} "
                  f"{fmt(s['mad'],8)} {fmt(s['p90'],9)} {fmt(s['p99'],9)}")


def cmd_compare(base_path, var_path, as_json):
    base, var = load(base_path), load(var_path)
    rows = []
    for m in METRIC_ORDER:
        a = [x for x in base.get("samples", {}).get(m, []) if x is not None]
        b = [x for x in var.get("samples", {}).get(m, []) if x is not None]
        if not a or not b:
            continue
        ma, mb = st.median(a), st.median(b)
        delta = mb - ma
        pct = (delta / ma * 100.0) if ma else float("nan")
        n = min(2000, 10000)
        diffs = []
        for _ in range(n):
            sa = [a[random.randrange(len(a))] for _ in range(len(a))]
            sb = [b[random.randrange(len(b))] for _ in range(len(b))]
            diffs.append(st.median(sb) - st.median(sa))
        diffs.sort()
        d_lo, d_hi = percentile(diffs, 2.5), percentile(diffs, 97.5)
        u, p = mann_whitney_u(a, b)
        rows.append({
            "metric": m, "base_median": ma, "var_median": mb,
            "delta_ms": delta, "delta_pct": pct,
            "delta_ci95_lo": d_lo, "delta_ci95_hi": d_hi,
            "mwu_p": p, "n_base": len(a), "n_var": len(b),
            "significant": (p < 0.05) and not (d_lo <= 0 <= d_hi),
        })
    if as_json:
        json.dump({"baseline": base_path, "variant": var_path, "rows": rows},
                  sys.stdout, indent=2)
        sys.stdout.write("\n")
        return
    base_lbl = base.get("label") or base_path
    var_lbl = var.get("label") or var_path
    print(f"baseline: {base_lbl}")
    print(f"variant : {var_lbl}")
    print(f"\n{'metric':22} {'base':>9} {'variant':>9} {'delta':>9} "
          f"{'delta%':>8} {'delta 95% CI':>20} {'p':>8} sig")
    for r in rows:
        ci = f"[{fmt(r['delta_ci95_lo'],0)},{fmt(r['delta_ci95_hi'],0)}]"
        sig = "*" if r["significant"] else ""
        print(f"{r['metric']:22} {fmt(r['base_median'],9)} "
              f"{fmt(r['var_median'],9)} {fmt(r['delta_ms'],9)} "
              f"{fmt(r['delta_pct'],8,1)} {ci:>20} {fmt(r['mwu_p'],8,4)} {sig}")
    print("\n*  = median moved AND 95% CI excludes 0 AND Mann-Whitney p<0.05")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("summarize")
    s.add_argument("paths", nargs="+")
    s.add_argument("--json", action="store_true")
    c = sub.add_parser("compare")
    c.add_argument("baseline")
    c.add_argument("variant")
    c.add_argument("--json", action="store_true")
    args = ap.parse_args()
    if args.cmd == "summarize":
        cmd_summarize(args.paths, args.json)
    else:
        cmd_compare(args.baseline, args.variant, args.json)


if __name__ == "__main__":
    main()
