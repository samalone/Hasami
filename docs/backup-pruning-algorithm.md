# Backup pruning algorithm: radix-based priority selection

## Overview

This document describes a backup pruning algorithm that selects which backups to retain from a collection of backups taken at arbitrary times. The algorithm has these properties:

- It works with backups taken on irregular schedules.
- It retains more recent backups and progressively fewer older ones, so that the gaps between retained backups grow with age.
- It is deterministic: given the same set of backups and the same parameters, it always selects the same ones.
- It is granularity-independent: the slot duration parameter affects only deduplication of very close backups, not the overall distribution of retained backups across time.
- It is simple to implement: the core is a sort with a custom key function, followed by truncation.

## Parameters

The algorithm takes three parameters:

- **radix** (integer ≥ 2): Controls how aggressively older backups thin out. With radix 2, the gap between retained backups roughly doubles at each step. With radix 3, it roughly triples. Radix 2 is the recommended default.
- **slot_duration** (time interval): The minimum time resolution. Backups closer together than this are treated as duplicates (only the most recent is kept). This should be set to a value smaller than the minimum expected interval between backups. For example, if backups occur at most once per hour, a slot duration of 1 second or 1 minute is fine.
- **keep_count** (integer ≥ 0): The maximum number of backups to retain.

## Algorithm

### Step 1: Compute age in slots

For each backup, compute its age relative to the current time (or a reference time), measured in units of `slot_duration`:

```
age_in_slots = floor((now - backup_timestamp) / slot_duration)
```

### Step 2: Deduplicate

If multiple backups map to the same `age_in_slots` value, keep only the one with the most recent timestamp. Discard the rest before proceeding.

### Step 3: Compute priority key

For each remaining backup, compute a priority key from its `age_in_slots` value. The key is a tuple `(reversed_value, tier)` computed as follows:

1. If `age_in_slots` is 0, the key is `(0, 0)`.
2. Otherwise, extract the digits of `age_in_slots` in the given radix by repeated division:

```
digits = []
remaining = age_in_slots
while remaining > 0:
    digits.append(remaining % radix)
    remaining = remaining / radix   (integer division)
```

3. The **tier** is the number of digits extracted (i.e., the length of the `digits` list). This equals `floor(log_radix(age_in_slots)) + 1`.

4. The **reversed value** is obtained by interpreting the extracted digits (which are in LSB-first order) as a base-N number:

```
reversed_value = 0
for each digit in digits:
    reversed_value = reversed_value * radix + digit
```

Note: Because the digit extraction via `% radix` / `/ radix` naturally produces digits in least-significant-first order, the "reversal" happens implicitly. There is no need for an explicit array-reverse step.

5. The priority key is the tuple `(reversed_value, tier)`.

### Step 4: Sort and select

Sort all deduplicated backups by their priority key in ascending order (comparing `reversed_value` first, then `tier` as a tiebreaker). Retain the first `keep_count` entries. Discard the rest.

## Why (reversed_value, tier) and not (tier, reversed_value)

The sort order is critical.

**If you sort by `(tier, reversed_value)`**: The algorithm fills each tier completely before moving to the next. Because higher tiers cover exponentially more time and contain exponentially more backups, the budget gets consumed by a single tier, leaving no representation for older or newer time ranges.

**If you sort by `(reversed_value, tier)`**: The algorithm interleaves across tiers. The first "round" (lowest reversed values) picks one representative from each occupied tier — covering the full time span. The second round picks the next-best representative from each tier, refining coverage everywhere simultaneously. This ensures that every time scale gets representation before any single tier consumes the budget.

## How it produces the desired distribution

### Tier structure

The tier of an age is the number of digits in its base-N representation. Tier K covers ages in the range `[N^(K-1), N^K - 1]` (with tier 1 covering just age 1). Each tier spans N times more time than the previous tier.

For base 2: tier 1 covers age 1, tier 2 covers ages 2–3, tier 3 covers ages 4–7, tier 4 covers ages 8–15, and so on.

### Digit reversal as a spacing heuristic

Within a tier, the reversed value prioritizes the "roundest" ages — those that are multiples of the largest powers of N. For example, in tier 4 (ages 8–15), the priority order is 8, 12, 10, 14, 9, 13, 11, 15. The multiples of 4 come first (8, 12), then the multiples of 2 that aren't multiples of 4 (10, 14), then the odd numbers (9, 13, 11, 15). This produces well-spaced representatives.

### Cross-tier interleaving

Because `reversed_value` is the primary sort key, all ages with the same reversed value (one from each tier) are grouped together, ordered by tier. The algorithm picks representatives from every tier before picking a second representative from any tier. The result is that with base 2 and `keep_count = K`:

- The first ~`T` picks (where T is the number of occupied tiers) cover the full time span with one backup per tier.
- The next ~`T` picks double the resolution within each tier.
- Each subsequent round of ~`T` picks doubles the resolution again.

This produces gaps between retained backups that grow geometrically with age, regardless of the total time span or the slot duration.

### Example

180 daily backups over 6 months, base 2, keep 20:

```
Kept (days): 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, 40, 48, 64, 80, 96, 128, 160
Gaps (days): 1, 1, 1, 1, 1, 2, 2, 2, 4, 4, 4, 8, 8, 8, 16, 16, 16, 32, 32
```

The gaps double roughly every three steps (because each "round" of interleaving contributes about `log2(180/slot_count)` picks across the occupied tiers). Recent backups are daily; the oldest gap is 32 days.

## Tree interpretation

The algorithm has a natural interpretation as a breadth-first traversal of an N-ary tree:

- The root node is age 1.
- Each node at age `A` has `N` children. Child `d` (for d = 0, 1, ..., N-1) has age `N^K + d * N^(K-1) + (A - N^(K-1))`, where K is the number of digits in A's base-N representation.
- The tree depth equals the tier number.
- Each parent is the coarse representative for its subtree's time range. Its children refine that range into N equal parts.
- Breadth-first traversal of this tree, skipping nodes that have no corresponding backup, produces exactly the priority ordering described above.

This means "keep the first X backups" is equivalent to "do a BFS of the priority tree, skipping empty nodes, and stop after X."

## Handling edge cases

- **Age 0** (a backup taken at exactly the reference time): Gets priority key `(0, 0)`, which sorts before everything else. It will always be retained if present.
- **Very large ages**: The algorithm handles arbitrarily large ages. The tier count grows logarithmically with the maximum age, and the interleaving ensures budget is distributed across all tiers regardless.
- **Fewer backups than keep_count**: All backups are retained. No pruning occurs.
- **Empty input**: Returns an empty list.
- **Duplicate timestamps**: The deduplication step (step 2) handles this by keeping only the most recent backup per slot.

## Reference implementation (Python)

```python
def priority_key(age: int, radix: int) -> tuple[int, int]:
    if age <= 0:
        return (0, 0)
    digits = []
    remaining = age
    while remaining > 0:
        digits.append(remaining % radix)
        remaining //= radix
    tier = len(digits)
    reversed_value = 0
    for d in digits:
        reversed_value = reversed_value * radix + d
    return (reversed_value, tier)


def select_backups_to_keep(
    backup_timestamps: list,  # list of datetime objects
    now,                      # datetime: the reference time
    radix: int,               # base for the priority calculation
    slot_duration: float,     # slot size in seconds
    keep_count: int,          # max backups to retain
) -> list:
    # Step 1 & 2: Compute ages and deduplicate
    by_slot = {}
    for ts in backup_timestamps:
        age = max(0, int((now - ts).total_seconds() / slot_duration))
        if age not in by_slot or ts > by_slot[age]:
            by_slot[age] = ts

    # Step 3 & 4: Sort by priority key, take top keep_count
    ranked = sorted(by_slot.items(), key=lambda pair: priority_key(pair[0], radix))
    kept_timestamps = [ts for age, ts in ranked[:keep_count]]

    return sorted(kept_timestamps, reverse=True)  # newest first
```
