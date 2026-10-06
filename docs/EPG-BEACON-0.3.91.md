# EPG performance beacons on 0.3.91

This branch starts at the committed and pushed `dev` build `31c1f4e` (which
contains the 0.3.91 settings release). It adds only EPG measurement code, tests,
and a reusable test script. The previous 0.3.90 prototype and the uncommitted
0.3.91 port remain in their separate worktrees.

Per Roku's [performance guide](https://developer.roku.com/dev/docs/measuring-channel-performance),
the viewer's Back or remapped guide-return key from the live player signals
`EPGLaunchInitiate`. `GuideView.onActive` signals `EPGLaunchComplete` after the
grid is drawn and focused. The app does not invent a keypress when the initial
home screen is already the EPG, and records only the first pair per session.

To exercise the path, import `rasp/AerioTVEpgLaunch.rasp` into Roku Remote Tool
on a Roku with a saved, authorized connection. Confirm Select tunes a current
live channel and Back returns to a navigable guide. If Select opens details
instead, tune a current channel manually and restart the app before retesting.
Inspect port 8085 for `AppLaunchComplete`, `EPGLaunchInitiate`, and
`EPGLaunchComplete` in order, plus the resulting EPG duration and memory points.

Roku states that only EPG measurements initiated within five seconds of
`AppLaunchComplete` qualify for certification. This tune-and-return script
may exceed that limit; ask Roku Partner Success how it applies when the EPG
itself is the app's home page. The unrelated cloud launch-plus-pause script
never sends a keypress, so this path cannot explain its reported reboot.

## Native check

`npm run verify` passed on the committed-dev-based source and produced a
195-file v0.3.91 ZIP (SHA-256
`99b31673daea6927b5e281c42610e6a97692228cbeb3a80b8cb042a19b61c2ff`).
The Roku developer installer accepted that exact ZIP on a Streaming Stick 4K
3820RW2 running Roku OS 15.3.4 / build 2402. The app launched as `dev`
v0.3.91. With a saved authorized 36-channel lineup, a fresh ECP launch emitted
`AppLaunchComplete`; Select entered the live player (`/query/media-player`
reported `play`); Back returned to the visible, focused EPG. The native
BrightScript console emitted `EPGLaunchInitiate` then `EPGLaunchComplete` in
that order. The live player remained `play` in the guide's mini-player; no
retune was required. A locally inspected screenshot shows the navigable guide;
it stays under ignored `out/` and is not published. Uptime increased from
639392 seconds before install to 639593 after the test, and `dev` remained
active. Console capture recorded only beacon names, not private stream data.

This is a native first-pair/return-to-guide check, not a five-second EPG
certification measurement: the script waited for the guide and live player
before Back, and the production Dashboard has not run the new build.
