# Remote device session - 0.3.37

The exact `out/release/aeriotv-roku-v0.3.37.zip` passed SHA256SUMS verification,
installed successfully through Developer Mode, and emitted the AerioTV native
launcher marker. ECP `/query/active-app` confirmed AerioTV Roku Preview **0.3.37**.

`npm run release:prepare` passed all BrightScript suites, package/tool tests,
compiler validation, build, and ZIP inspection (127 files). The production
dependency audit reported zero vulnerabilities.

The physical RM01–RM10 all-PASS acceptance applies to the development candidate
documented in `REMOTE-MAP-CONTROLLER-VERIFICATION.md`. The release advances version
metadata for delivery of those accepted repairs. This exact-artifact check is
installation/launch evidence, not a claim that the physical matrix was rerun.
