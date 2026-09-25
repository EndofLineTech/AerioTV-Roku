# Saved-connection roster failure boundary — 0.3.80 development candidate

`AerioTV-Roku-itx` followed a one-time loss of the selected legacy/Main
connection during older disposable probe sideloads. Controlled repeats did
not reproduce the original registry state, so its historical cause is still
unknown. Current scoped Forget, normal and failed-startup probe sideloads
previously preserved other saved slots; a genuinely absent `connectionsV1`
can recover the non-secret legacy server/Remember metadata and separately
scoped API key when those values still exist.

The investigation did find a concrete unsafe interpretation: a **non-empty**
saved roster with truncated JSON or an unexpected JSON root was normalized
to an empty first-run store. That could show Welcome/Add and permit a later
save to overwrite the unreadable original bytes, masking the problem and
discarding recoverable slots. It now loads as a **read-only** recovery state,
not a new installation; writes fail rather than overwriting the original.
Only an actually missing roster follows the existing legacy fallback.

Model tests cover truncated input, JSON null/array/number, preservation of
the original value and failed writes, while genuine absence still loads the
legacy slot. An isolated native probe wrote dummy legacy metadata and a
corrupt roster only in its separate `AerioTVMigrationProbeV1` registry
section. It returned migration/recovery PASS, retained the dummy scoped key
and corrupt bytes, and did not touch the real AerioTV registry. After the
normal app was restored, a private device capture showed the remembered
authorized guide; no first-run/reset screen appeared.

This protection prevents a corrupt non-empty roster from being mislabeled
and overwritten. It does **not** reconstruct entries from arbitrary corrupt
JSON or prove that the older unexplained disappearance had that exact cause.
If a wholly missing registry also lacks legacy metadata, no source of truth
is available for automatic recovery; an observed recurrence needs fresh
redacted diagnostics rather than a speculative migration.
