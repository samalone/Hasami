# Backup pruning algorithm: CDF warp + greedy thinning

## Overview

This document describes the backup pruning algorithm Hasami uses to select which
backups to retain from a collection taken at arbitrary times. The algorithm has
these properties:

- It works with backups taken on irregular schedules.
- It distributes the retained backups to fit an **exponential-decay retention
  curve**: recent backups are kept densely, and the spacing between retained
  backups grows with age.
- It keeps *exactly* `keep_count` backups when more than that many are available
  (no fractional-budget rounding that under- or over-shoots).
- It is deterministic: given the same set of backups and parameters, it always
  selects the same ones, regardless of input order.
- It consults no wall-clock time. Ages are measured relative to the newest backup
  in the input, so the output is a pure function of the input set, and re-running
  on an unchanged set is a no-op.

## The key idea: warp time so the target density becomes uniform

Instead of reasoning about an exponential directly, warp age into a coordinate in
which the target retention density is *uniform*, then keep points evenly spaced in
that coordinate.

The target retention density as a function of age is `d(t) ∝ 2^(−t / H)`, where
`t` is age (measured from the newest backup) and `H` is the **half-life** — the
age over which retention density halves. The integral of that density (its CDF) is

```
u(t) = 1 − 2^(−t / H)
```

with the newest backup at `t = 0 → u = 0`, and `u` rising toward 1 as age
increases. The useful property: `u(t_j) − u(t_i)` is the fraction of the ideal
backup population that should fall between backups *i* and *j*. So if retained
backups are evenly spaced in `u`, each one "represents" an equal slice of the
target distribution — and evenly-spaced-in-`u` is, by construction,
exponentially-decaying-in-`t`. We never reason about the exponential directly
again; we just keep points roughly uniform in `u`.

## Parameters

- **half-life** (`H`): the age over which retention density halves. Hasami offers
  two ways to set it (see [Two ways to set the half-life](#two-ways-to-set-the-half-life)).
- **keep_count** (`N`, integer ≥ 0): the maximum number of backups to retain.

The base of the warp is fixed at 2, so `H` is a literal half-life: the retained
density halves for every `H` of additional age.

## Algorithm

1. **Compute ages.** Let `newest` be the most recent timestamp in the input. For
   each backup, `age = newest − timestamp` (≥ 0). The newest backup has age 0.

2. **Handle the easy cases.** If `N = 0` or the input is empty, return nothing. If
   the input has no more than `N` backups, return all of them. If `N = 1`, return
   just the newest.

3. **Warp.** For each backup compute `u = 1 − 2^(−age / H)`.

4. **Pin the endpoints.** The newest backup is always retained. The oldest backup
   is also pinned by default, so the retained set always spans the full history.
   Only the interior backups are candidates for removal.

5. **Greedily thin the most redundant backup.** Maintain the surviving backups as
   a doubly-linked sequence. For each interior survivor, its *merge cost* is the
   `u`-distance between its two neighbors — the gap that would be left if it were
   removed:

   ```
   cost(p) = | u[next(p)] − u[prev(p)] |
   ```

   Repeatedly remove the interior survivor with the **smallest** merge cost — the
   one sitting in the densest `u`-cluster, representing the least target mass, i.e.
   the most redundant one — and recompute the cost of its two neighbors. Stop when
   `N` backups remain.

6. **Return** the survivors, sorted newest-first.

A min-heap with lazy invalidation (re-cost on pop, version-stamp stale entries)
makes this `O(M log M)`, where `M` is the number of backups. `M` is tiny in
practice, so performance is a non-issue.

### Why greedy thinning of the smallest gap

Removing the backup whose neighbors are closest in `u` is removing the one that
contributes least to covering the target distribution. Doing this repeatedly
keeps the worst remaining `u`-gap as small as possible and drives the surviving
set toward uniform `u`-spacing — which is exactly exponential spacing in time.
The long tail, where the target would otherwise ask for "0.3 backups per `H`,"
simply becomes one large `u`-gap that naturally holds a single backup, with no
fractional rounding and no discontinuities at bucket edges.

## Two ways to set the half-life

The algorithm only depends on `H`. The two modes differ solely in where `H` comes
from, and share a single implementation.

- **Absolute half-life.** `H` is a fixed real duration (e.g. 30 days). Retention
  density halves every `H` of real time; the retained shape depends on how far
  back the backups actually span. Backups older than several `H` collapse toward a
  single representative in the tail. CLI: `--half-life 30d`.

- **Relative to the history span.** `H = span / k`, where `span` is the difference
  between the newest and oldest timestamps and `k` is how many half-lives fit
  across the full history. This makes the retained shape *scale-free* — identical
  whether the history covers a week or a decade — and avoids any numerical
  underflow in the tail. CLI: `--half-lives 4` (meaning `span / 4`). This is the
  default mode, with `k = 4`.

The relative mode is just the absolute mode with `H` pre-computed from the data:
`retainedBackups(halfLivesAcrossSpan: k, …)` computes `H = span / k` and calls
`retainedBackups(halfLife: H, …)`.

## Two design decisions

**Reference point.** Ages are anchored to the newest backup, not wall-clock
"now." The consequence is idempotence over time: if no new backup arrives,
re-running is a no-op, so backups are only ever deleted *because new ones were
taken*. Anchoring to "now" instead would slowly age everything out and prune even
when nothing new was captured.

**Endpoints.** Keeping the newest is required (it anchors the warp). Keeping the
oldest is the default so the retained set always spans the full history rather
than letting the tail erode across re-runs.

## Example

180 evenly-spaced backups (timestamps 1…180), relative half-life `span / 4`
(`H = 179 / 4 ≈ 44.75`), keep 20. Ages are measured from the newest (timestamp
180):

```
Kept (ages):  0, 3, 7, 11, 15, 19, 23, 27, 31, 35, 43, 51, 59, 67, 75, 83, 99, 115, 147, 179
Gaps:           3, 4, 4, 4, 4, 4, 4, 4, 4, 8, 8, 8, 8, 8, 8, 16, 16, 32, 32
```

The gaps grow with age (≈3 → 4 → 8 → 16 → 32), fitting the exponential-decay
curve. Recent backups are dense; both the newest (age 0) and the oldest (age 179)
are retained.

## Handling edge cases

- **Newest backup**: age 0, `u = 0`; always retained.
- **Oldest backup**: pinned by default; always retained when `keep_count ≥ 2`.
- **Fewer backups than `keep_count`**: all are retained; no pruning occurs.
- **Empty input** or **`keep_count = 0`**: returns an empty list.
- **`keep_count = 1`**: returns only the newest backup.
- **All timestamps identical** (degenerate span): there is at most one distinct
  timestamp, so the count guard returns everything; the half-life value is
  irrelevant.
- **Duplicate timestamps**: collapse to a single entry before ranking. Callers
  that attach metadata to each timestamp (e.g. the `sukashi-plan` CLI) decide
  which duplicate to keep; the algorithm itself only sees the set of distinct
  timestamps.
- **Cost ties**: when two interior backups would leave exactly equal `u`-gaps,
  the tie is broken deterministically (by position) so the result is invariant to
  input order.

## Reference implementation (Python)

```python
import heapq

def retained_backups(timestamps, half_life, keep_count):
    """Return the timestamps to keep, newest-first."""
    points = sorted(set(timestamps))            # ascending: oldest -> newest
    n = len(points)
    if keep_count <= 0 or n == 0:
        return []
    if n <= keep_count:
        return points[::-1]
    if keep_count == 1:
        return [points[-1]]

    newest = points[-1]
    u = [1.0 - 2.0 ** (-(newest - ts) / half_life) for ts in points]

    prev = list(range(-1, n - 1))
    nxt = list(range(1, n + 1))
    alive = [True] * n
    version = [0] * n

    def cost(i):
        return abs(u[nxt[i]] - u[prev[i]])

    heap = []                                   # (cost, index, version); ties by index
    for i in range(1, n - 1):
        heapq.heappush(heap, (cost(i), i, version[i]))

    survivors = n
    while survivors > keep_count:
        c, i, v = heapq.heappop(heap)
        if not alive[i] or v != version[i]:     # stale entry
            continue
        alive[i] = False
        survivors -= 1
        p, q = prev[i], nxt[i]
        nxt[p], prev[q] = q, p
        for m in (p, q):
            if 0 < m < n - 1:
                version[m] += 1
                heapq.heappush(heap, (cost(m), m, version[m]))

    return [points[i] for i in range(n - 1, -1, -1) if alive[i]]


def retained_backups_relative(timestamps, half_lives_across_span, keep_count):
    distinct = sorted(set(timestamps))
    span = distinct[-1] - distinct[0] if len(distinct) >= 2 else 0
    half_life = (span / half_lives_across_span) if span > 0 else 1.0
    return retained_backups(timestamps, half_life, keep_count)
```
