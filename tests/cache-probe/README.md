# Native metadata/storage measurement

This separate development package is excluded from the normal app. It reads the
existing AerioTV remembered server/API key in device memory (if enabled), sends
read-only metadata requests, and prints only counters—not raw responses or keys.
It uses its own `AerioTVStorageProbe` registry section and filesystem directories.

Set `cache_probe_phase` in this fixture's manifest:
- `seed`: storage plus API/memory measurements; leaves tiny sentinel markers.
- `storage`: storage measurements without API calls.
- `verify`: checks sentinel retention, deletes probe directories/registry section.

From this directory run `../../node_modules/.bin/bsc --project bsconfig.json`.
From the repository root, with `ROKU_HOST` and `ROKU_DEV_PASSWORD` supplied in the
environment, run:

```sh
python3 scripts/run-native-probe.py out/cache-probe.zip --timeout 180 --marker '[cache-probe-main]'
```

The probe closes its own Scene when complete. Use seed then verify in separate
installations to check process-boundary retention. This is not a physical reboot
or a Home-key test. After verification, reinstall the normal app ZIP.

The first storage fixture's large String() repeat was not a valid byte-volume
test. The corrected code doubles an explicit string, asserts/report its byte
count, and retains the files for a telemetry sample. It writes at most 8 MiB per
tested volume, aborts under memory pressure, and never tries to exhaust quota.
