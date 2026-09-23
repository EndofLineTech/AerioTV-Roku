# DVR confirmation — development 0.3.59

The recording confirmation now shows the bounded program title, channel,
**padded local start and end date/time**, and the selected early/late minute
values. Long titles are clipped before assembling the message so they cannot
hide its timing and padding. `tests/DvrPresentationModel.test.brs` checks
adjusted dates/times and long-title visibility. `npm run verify` passed and
the normal `0.3.59` package installed on the Streaming Stick 4K.

On the installed build the future guide detail led to a confirmation visibly
showing the correct local 2:00–3:00 PM window, 0/0 padding and a default
Cancel button. Cancel returned to the guide without a POST. The **single**
owner-approved disposable schedule/exit/cancel/removal test ran on `0.3.58`;
see `docs/DVR-UI-0.3.58.md`. No second recording was created on `0.3.59`.
Device screenshots are private and ignored in `out/`. Physical-remote and
speaker acceptance, repeat-OK and server failure cases are still separate.
