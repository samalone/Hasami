# SUKASHI-PLAN(1) - Hasami Plan Generator

## NAME

sukashi-plan - Emit a keep or prune plan for timestamped items read from stdin

## SYNOPSIS

```bash
sukashi-plan --mode <keep|prune> [OPTIONS]
```

## DESCRIPTION

`sukashi-plan` exposes the Hasami sukashi (透かし) pruning algorithm as a
stdin/stdout filter. It reads timestamped items from stdin, runs the same
radix-based priority selection that `sukashi(1)` uses, and writes either the
retained keys or the discarded keys to stdout — one per line, preserving the
order they appeared on input.

Unlike `sukashi(1)`, this tool never touches the filesystem. Keys are opaque
strings; the tool doesn't care whether they name files, S3 prefixes, database
rows, or anything else. That makes it suitable for pruning cloud object
storage, pruning database rows by timestamp, or any pipeline where the actual
deletion is someone else's job.

## INPUT FORMAT

One item per line on stdin:

```
<unix-timestamp><TAB><key>
```

- `<unix-timestamp>` is an integer number of seconds since the Unix epoch.
- `<key>` is any non-empty string. Only the first tab on the line separates
  the timestamp from the key; additional tabs are part of the key.
- Empty lines are ignored.
- Malformed lines (missing tab, non-integer timestamp, empty key) cause the
  tool to exit non-zero and report the 1-based line number on stderr.

## OUTPUT

The keys that should be retained (`--mode keep`) or the keys that should be
removed (`--mode prune`), one per line, on stdout. Every input key appears in
exactly one of the two modes' output.

## OPTIONS

- `--mode <keep|prune>`

  Which keys to emit. Required; there is no default. Forcing the caller to
  pick makes it harder to accidentally pipe a retain-list into a delete
  command.

- `-r, --retain <number>`

  Number of items to retain (default: 10). Must be non-negative.

- `-x, --radix <number>`

  Radix for the pruning algorithm (default: 2). Controls how aggressively
  older backups thin out: with radix 2 gaps roughly double, with radix 3
  they roughly triple. Must be at least 2.

- `-h, --help`

  Show help.

## EXAMPLES

### Pruning dated S3 prefixes with rclone

```bash
rclone lsjson ess-prod:ess-backups/snapshots/ --dirs-only \
  | jq -r '.[] | "\(.ModTime | fromdateiso8601)\t\(.Name)"' \
  | sukashi-plan --retain 30 --radix 2 --mode prune \
  | xargs -r -I{} rclone purge "ess-prod:ess-backups/snapshots/{}"
```

### Previewing the retain set

```bash
cat snapshots.tsv | sukashi-plan --mode keep --retain 20
```

### Pruning database rows

```bash
psql -tAc "SELECT extract(epoch FROM created_at)::int || E'\t' || id FROM snapshots" \
  | sukashi-plan --mode prune --retain 50 \
  | xargs -r -I{} psql -c "DELETE FROM snapshots WHERE id = '{}'"
```

## EXIT CODES

- `0` — Success (including empty stdin, which is a valid no-op).
- `64` — Usage error (missing `--mode`, invalid flag values).
- `65` — Malformed input on stdin.

## ALGORITHM

Identical to `sukashi(1)`; see
[docs/backup-pruning-algorithm.md](docs/backup-pruning-algorithm.md) for the
full specification. Both tools link the same `Hasami` library, so there is
no algorithmic divergence between filesystem pruning and pipeline pruning.

## SEE ALSO

- `sukashi(1)` — filesystem-rooted, Trash-aware variant for local backup
  directories.
- [Algorithm Specification](docs/backup-pruning-algorithm.md)
