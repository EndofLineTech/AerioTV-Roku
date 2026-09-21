# Remote device session - 0.3.36

Date: 2026-09-21. Controlled installation and launch evidence only.

- `npm run release:prepare` passed unit suites, package/tool tests, compiler,
  build, and package inspection. Production dependency audit found no vulnerabilities.
- The exact `aeriotv-roku-v0.3.36.zip` passed `SHA256SUMS` verification.
- Developer Mode installation succeeded on the configured Roku target.
- The native console reported the AerioTV launcher marker.
- ECP `/query/active-app` confirmed AerioTV Roku Preview version `0.3.36`.

The Product Owner approved publishing this testing prerelease with affected-account
guide recovery and VOD category confirmation still open. This launch check does
not establish those results, physical remote-map acceptance, accessibility, or
endurance behavior.
