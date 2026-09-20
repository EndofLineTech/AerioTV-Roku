# Top-level navigation and English descriptions — 0.3.19

Implements the PO's notes on the completed 0.3.17 worksheet. Those results are
preserved. The broader categorized Settings hub (`b17.2`) is not declared complete.

## Navigation

The guide and library show **Live TV / VOD** across the top. VOD additionally shows
**Movies / TV Shows** tabs, with allowed destinations derived from capabilities.
Disabled destinations cannot take focus or launch a request.

From any guide row:
- Sidebar layout: hold Left to Groups, then Left to top navigation.
- Pills layout: hold Left to Groups, then Up to top navigation.
- Modal layout: hold Left directly to top navigation; a short Left still navigates
  guide time, now on release rather than on initial press.
- From the first guide channel, Up follows the visible hierarchy: groups then the
  header for docked layouts, or directly to the header for modal layout.

Left/Right selects a header destination and OK commits it. Moving focus alone does
not stop a mini-player. Selecting VOD performs the existing local playback teardown.
Down enters the content below; Back from a header returns to content rather than
exiting the app. Existing guide group navigation and star-menu access remain.

In VOD, Up from the first tile row reaches Movies/TV Shows. Up again reaches
Live TV/VOD. Live TV returns to the guide, preserving its position. Library tabs
use the existing per-account movie/series bookmarks and normal authorization checks.

## Description diagnosis and policy

Native metadata inspection found:
- No optional TMDB API key configured on this Roku.
- The sampled Matrix catalog description was English.
- The shared DS9 description was French. The configured provider relations also
  contained a German summary and an English summary in `basic_data.plot`.

The client now preserves a recognizable English base summary rather than replacing
it with localized provider-info text. If movie/series details still lack English,
an asynchronous Task searches available provider metadata without blocking Play.
Only description text changes; playback source, container, title identity, buttons
and focus are retained. Episode metadata also prefers English descriptions when
the selected provider supplies them during its existing detail request.

This uses a conservative word-based English preference, not machine translation.
It does not treat a film's original/audio language as the synopsis language.
Short or mixed text can remain unconfirmed. When no alternate English summary is
found, the original text remains visible with an explicit fallback notice. No
TMDB credentials are extracted from another system, and no translation service or
new runtime service is introduced.

Enrichment rechecks account identity/capabilities and the detail permission
fingerprint, cancels with its owner dialog, and rejects stale-title callbacks.
Provider relations use the existing 8-MiB ceiling; individual supplemental requests
use 1 MiB. At most two additional movie-provider detail requests fit within the
12-second Task budget. English results use the existing account-scoped five-minute
metadata cache, keyed by title and language policy version.

## Verification

- 42 suites include navigation boundaries/disabled destinations, docked-group and
  modal hold-Left routes, English preference/fallback, and actual description
  callback tests for stale events, preserved dialog/buttons/focus, and failed lookup.
- Native production UI: guide header focus -> VOD Movies -> TV Shows -> DS9 details
  reported English, same Dialog node and same button count -> Back restored library
  focus -> Live TV restored guide focus. No media was started by the fixture.
- Native screenshots inspected the guide/sidebar and VOD layouts. Headers, tabs,
  rows and footer were visibly separated. Screenshots are local build artifacts.
- Temporary probe hooks were removed before the normal build was restored.

Physical retest instructions are in `RETEST-0.3.19.txt`. Native scripted evidence
does not pre-fill that worksheet or imply that every provider has English metadata.
