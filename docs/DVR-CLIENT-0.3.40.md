# Dispatcharr DVR client (development 0.3.40)

The task-layer client is `DvrRecordingTask` (`schedule`, `cancel`, `list`,
`status`). It is not connected to the guide or player yet; no recording
control is advertised in the Roku UI.

Contract checked against Dispatcharr **v0.31.0**
[`api_urls.py`](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/api_urls.py),
[`RecordingSerializer`](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/serializers.py),
and [DVR access tests](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/tests/test_dvr_access.py):

- `GET`/`POST /api/channels/recordings/`, `GET`/`DELETE /api/channels/recordings/{integer-id}/`.
- POST sends the integer channel ID and ISO-8601 UTC start/end times; the
  server does **not** schedule by program ID or accept `pre_roll`/`post_roll`.
- Roku adds requested padding (0–120 minutes) to the selected guide times.
  The POST stores `roku_program_id` and `roku_program_title` in
  `custom_properties`. It intentionally omits nested `program`: v0.31.0
  applies server-wide DVR offsets again when that object is present.
- `dvr_access=manage` is required for create/delete; view permits list/get.
  The server remains the authority for permissions and scheduling.
- Before POST, the client loads recordings and refuses another active schedule
  for the same channel/program or exact padded times. A UI caller must also
  disable repeat submissions: the preflight is not a server-side atomic
  idempotency key. On an ambiguous timeout, refresh the server list first.
- DELETE accepts an empty 204 response and never retries mutations. HTTP
  conflict (409), permission (403), and transport failures surface categories.
  Only unsigned numeric recording IDs may enter detail URLs.
- The `cancel` task action fetches the recording first and refuses DELETE unless
  the item is still scheduled to start in the future. Dispatcharr's DELETE
  destroys completed recordings too; the parent management story must keep
  Stop, Cancel and Delete distinct. A status read cannot eliminate a race with
  another client changing the server record before DELETE.

`tests/DvrRecordingModel.test.brs` exercises request paths, padded POST,
duplicate detection, permission failure and DELETE dispatch;
`tests/HttpPolicy.test.brs` covers empty DELETE and no mutation retry.
An isolated development **0.3.46 native probe** (excluded from the normal ZIP)
used the Roku's signed-in Dispatcharr 0.31.0 session, selected one future
program from its authorized guide, scheduled exactly one disposable recording,
GET-verified the returned channel/program identity, cancelled only the new
future recording and GET-verified its removal. The first 0.3.43/0.3.44 probe
attempts performed **no server write**: they exposed that native EPG epochs
arrive as `roInt`, while the client initially accepted only `Integer`. The
corrected client accepts integer interfaces. No URL, credential or media label
was exported in evidence; the probe was removed when the normal app was
restored. This verifies the API client path, **not** server ownership after the
Roku exits. Guide/player UI actions, physical use and after-exit verification
remain in the parent recording story.
