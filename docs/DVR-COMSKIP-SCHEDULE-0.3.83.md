# Schedule-time Comskip contract — AerioTV-Roku-dwi

## Conclusion

**Dispatcharr v0.31.0 does not implement a per-recording schedule-time
Comskip choice.** Do not expose a Roku On/Off schedule toggle: On would not
guarantee processing, and Off would not prevent processing when the server's
global DVR Comskip setting is enabled. The Roku's existing, permission-checked
**Queue commercial processing** action on a completed recording remains the
supported per-item control. No shared server setting or recording was changed
during this review.

## Pinned contract evidence

- [RecordingSerializer](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/serializers.py#L774-L808)
  accepts non-storage `custom_properties` keys, so the tvOS/Android pattern of
  submitting `custom_properties.comskip=true` may be stored. Acceptance by the
  serializer is **not** scheduling behavior.
- The [recording finalizer](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/tasks.py#L2940-L2945)
  decides whether to enqueue `comskip_process_recording` using
  `CoreSettings.get_dvr_comskip_enabled()` alone, without inspecting a
  per-recording request. The [worker](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/tasks.py#L3264-L3275)
  reads `custom_properties.comskip` only as a **dictionary of processing
  status**, not a boolean preference; it later overwrites that field with
  result metadata. Thus an accepted boolean cannot provide an individual
  Off/On contract on this server version.
- The [explicit `POST /recordings/{id}/comskip/` action](https://github.com/Dispatcharr/Dispatcharr/blob/v0.31.0/apps/channels/api_views.py#L3452-L3461)
  enqueues processing when called. Roku already restricts its
  [post-recording action](../source/DvrRecordingModel.brs) to a confirmed
  completed or stopped item and DVR manage permission. The server's global
  mode may process recordings automatically, so a manual queue should not be
  presented as an automatic schedule-time override.
- [tvOS's schedule call](https://github.com/jonzey231/AerioTV/blob/8d5818456e0f4421d93b8ff120ad878d63331091/Networking/StreamingAPIs.swift#L3918-L3956)
  sends `custom_properties.comskip=true` when requested; Android's record
  sheet likewise forwards a boolean. Those client implementations do not
  change the pinned Dispatcharr finalizer's global-only decision.

## Condition for a future per-item control

If a supported Dispatcharr release adds a documented per-recording Comskip
request field and capability signal, gate a **default-Off**, one-shot schedule
choice on that capability and DVR manage permission. Recheck the persisted
per-item request and resulting worker status with a separately approved
disposable recording. Do not change server-wide settings or use an unbounded
Roku background poll to simulate schedule-time processing. Until then,
post-completion Queue is the accurate Roku action.
