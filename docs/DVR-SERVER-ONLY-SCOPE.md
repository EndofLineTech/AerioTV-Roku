# DVR storage scope on the Roku Streaming Stick 4K

The Product Owner chose **server-owned Dispatcharr DVR only** for this epic.
Roku-local capture, downloads, export and keep-awake recording are excluded;
the Roku is a remote control and authorized playback client for recordings
stored by the existing Dispatcharr server. Exiting the Roku app does not stop
server schedules, as the disposable `0.3.58` native exit/relaunch check showed.

This is supported by Roku's [file-system documentation](https://developer.roku.com/dev/docs/file-system.md):
`tmp:` contents are lost when the app exits; `cachefs:` may be evicted at any
time; `pkg:` and USB files are read-only (and USB is not on all devices); and
the persistent registry is limited to 32 KiB per app. None is a dependable
destination for full-length video on the tested Streaming Stick 4K. App-local
storage is used for bounded preferences, cache and transient HTTP files only.
No Roku-local media capture or downloaded-copy UI is advertised.
