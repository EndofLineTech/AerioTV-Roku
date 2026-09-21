# Development dependency review

Reviewed 2026-09-21 for the `0.3.30` development build. These dependencies are
only used for compilation and off-device model/controller tests. The Roku ZIP has
no JavaScript dependencies; `npm audit --omit=dev --json` reports zero production
vulnerabilities.

## Current resolution

`brs@0.39.0` remains the interpreter because its behavior is the regression-test
baseline. npm overrides resolve its transitive `source-map-resolve` to `0.5.0` and
`uuid` to `11.1.0`.

- The `source-map-resolve` override removes the vulnerable
  `decode-uri-component@0.2.2` path from the installed dependency tree.
- The `uuid` override preserves the `v4()` CommonJS API used by the interpreter.
- A clean `npm ci`, then `npm run verify`, passed with these resolutions.

`npm audit --json` still reports two moderate findings against `brs` and `uuid`.
The report keys off `brs`'s declared vulnerable `uuid` range even though
`npm ls uuid` resolves `11.1.0`. `npm audit fix --dry-run` proposes the unrelated
semver-major `brs@0.28.0`; it is not an acceptable supported update. Treat the
remaining entries as a development-tool audit exception, not as a clean audit.

## Rejected candidate

The current `brs@0.45.0` candidate was installed and audited in an isolated
temporary workspace. It introduces `decompress@4.2.1`, which has a critical
archive-extraction advisory. It also retains moderate `uuid` and
`decode-uri-component` findings. Do not upgrade to it without an upstream release
that removes the archive-extraction dependency and a full model-test revalidation.

## Reproduction

```sh
npm ci
npm run verify
npm ls uuid decode-uri-component source-map-resolve
npm audit --json
npm audit --omit=dev --json
```

Do not use `npm audit fix --force` for this project. It can replace the pinned
interpreter without validating the model-test semantics that it supplies.
