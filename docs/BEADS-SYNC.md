# Beads database synchronization

## Approved destination

The Product Owner approved the existing **public** repository
`https://github.com/EndofLineTech/AerioTV-Roku.git` for the full Beads database and
history. Dolt stores it at **refs/dolt/data**, independently of application Git
branches. This is public data, including issue descriptions, comments, and history.

The local database is `beads_AerioTV-Roku`, served on localhost port 3307. Its Dolt
branch is `main`; the application Git branch is `dev`. These are separate histories.

## Normal workflow

```bash
node scripts/beads-sync.mjs pull
# Use bd ready/show/create/update/close normally.
node scripts/beads-sync.mjs push
```

The wrapper uses `bd sql` and supported Dolt server procedures. It refuses dirty
working sets, unexpected destinations, and non-main database branches. Pull is
fast-forward only; push never forces. If there are uncommitted database changes,
review with `bd vc status` and use `bd vc commit -m "..."` before retrying.
If histories diverge, inspect the Dolt history and resolve the divergence explicitly.

Ordinary application `git push` does **not** push the database. `bd sync` is a
deprecated no-op, and JSONL is not the source of truth for this installation.
The historical `.beads/backlog-snapshot.json` is an archival subset, not a full
database backup or an automatically refreshed export.

## Why not bd dolt push?

Installed Beads **0.56.1** (`48bfaaad388b`) excludes the `dolt` command family from
database initialization in `cmd/bd/main.go`. Its push/pull handlers nevertheless
call `getStore()`, returning **no store available**. This does not mean the issue
database is missing: `bd sql` connects successfully. The wrapper bypasses this
command-initialization bug without changing the global Beads installation.

Also, this Beads version can report SQL errors in JSON while exiting zero. The
wrapper checks the JSON `error` field, not just the process exit status.

## Configure a new installation

Requires Dolt with Git-remote support (verified with **2.3.4**), Git, and GitHub
write access available to the OS user running the Dolt server. Do not put tokens
in the remote URL or repository files.

After restoring/connecting Beads to its database, check remotes:

```bash
bd sql 'SELECT name, url FROM dolt_remotes' --json
```

Only if `origin` is absent, configure it:

```bash
bd sql "CALL dolt_remote('add', 'origin', 'https://github.com/EndofLineTech/AerioTV-Roku.git')" --json
```

## Restore drill

Clone into a new scratch directory, never over the live database:

```bash
dolt clone https://github.com/EndofLineTech/AerioTV-Roku.git beads-restore
```

Inside that clone:

```bash
dolt sql -r json -q "SELECT dolt_hashof('HEAD') AS head"
dolt sql -r json -q "SELECT COUNT(*) AS issues FROM issues"
dolt sql -r json -q "SELECT COUNT(*) AS commits FROM dolt_log"
```

Compare with the same queries through `bd sql --json` on the live database.
A matching HEAD establishes restoration of the committed Dolt state and ancestry.
Uncommitted/ignored local data is not covered by a commit-based remote.

On 2026-09-21, the first push and independent GitHub clone matched HEAD
`o3tj15r56lrg0tal5atmk3af5is1sdhe`, with **206 issues and 573 commits**.
The restore did not replace or interrupt the live database.
