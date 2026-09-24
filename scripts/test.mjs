import { spawnSync } from 'node:child_process';

for (const suite of ['DispatcharrModel', 'GuideModel', 'XmltvModel', 'M3uModel', 'XtreamModel', 'XtreamTask', 'SceneUi', 'AerioSurface', 'RemoteHints', 'TaskSupport', 'PlaybackModel', 'NowNextModel', 'PreferenceModel', 'ConnectionStore', 'ConnectionNavigation', 'ConnectionAuthTask', 'CapabilityModel', 'ProgramSearchModel', 'PlayerLifecycle', 'VideoGeometry', 'StreamSourceTask', 'GuideSettingsModel', 'ReminderModel', 'GuideMenu', 'LogoCache', 'VideoInput', 'GuideInput', 'GroupInput', 'PlayerOkHold', 'PlayerRemoteInput', 'GuideRemoteInput', 'StartupRecovery', 'AacStartup', 'CapabilityTask', 'PlayerOptionsInput', 'MetadataCacheModel', 'HttpPolicy', 'DvrRecordingModel', 'DvrPresentationModel', 'DvrNavigation', 'DvrView', 'GuideTaskCache', 'GuideMappingFallback', 'MappingTask', 'LiveRecovery', 'PlaybackFailure', 'MediaSessionModel', 'VodModel', 'VodState', 'CatchupModel', 'DiagnosticModel', 'OnDemandPlayer', 'ArchiveController', 'VodSeriesLoader', 'NavigationModel', 'DescriptionModel', 'VodDescriptionInput', 'SettingsModel', 'PlayerInfoClock', 'TmdbModel', 'TmdbTask', 'VodShelfTask', 'RemoteMapModel', 'SettingsRail', 'SettingsHubInput']) {
  const result = spawnSync(process.execPath, [
    'node_modules/brs/bin/cli.js', '--root', 'tests/unit-root',
    'source/DispatcharrModel.brs', 'source/GuideModel.brs', 'source/SceneUi.brs', 'source/TaskSupport.brs',
    ...(suite === 'XmltvModel' ? ['source/XmltvModel.brs'] : []),
    ...(['M3uModel', 'PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['source/M3uModel.brs'] : []),
    ...(['XtreamModel', 'XtreamTask', 'PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['source/XtreamModel.brs'] : []),
    'source/PlaybackModel.brs',
    ...(suite === 'RemoteHints' ? ['components/RemoteHints.brs'] : []),
    ...(suite === 'AerioSurface' ? ['components/AerioSurface.brs'] : []),
    'source/NowNextModel.brs',
    'source/RemoteMapModel.brs', 'source/PreferenceModel.brs',
    ...(suite === 'ConnectionAuthTask' ? ['source/ChannelProfileModel.brs'] : []),
    ...(['ConnectionStore', 'ConnectionNavigation', 'PlayerLifecycle'].includes(suite) ? ['source/ConnectionStoreModel.brs'] : []),
    'source/CapabilityModel.brs',
    'source/ProgramSearchModel.brs',
    'source/VideoGeometry.brs',
    'source/GuideSettingsModel.brs',
    'source/ReminderModel.brs',
    ...(['TmdbTask', 'VodShelfTask'].includes(suite) ? [] : ['source/MetadataCacheModel.brs']),
    'source/HttpPolicy.brs',
    ...(suite === 'DvrRecordingModel' ? ['source/DvrRecordingModel.brs'] : []),
    ...(suite === 'DvrRecordingModel' ? ['source/DvrSeriesModel.brs'] : []),
    ...(['DvrPresentationModel', 'DvrNavigation', 'DvrView'].includes(suite) ? ['source/DvrPresentationModel.brs'] : []),
    'source/MediaSessionModel.brs', 'source/VodModel.brs', 'source/VodState.brs', 'source/CatchupModel.brs',
    'source/DiagnosticModel.brs',
    'source/NavigationModel.brs', 'source/DescriptionModel.brs',
    ...(['SettingsModel', 'SettingsRail', 'SettingsHubInput'].includes(suite) ? ['source/SettingsModel.brs'] : []),
    ...(['SettingsRail', 'SettingsHubInput'].includes(suite) ? ['components/SettingsRail.brs'] : []),
    ...(suite === 'SettingsHubInput' ? ['components/SettingsHub.brs'] : []),
    ...(suite === 'SettingsModel' ? ['components/SettingsNavigation.brs'] : []),
    ...(['TmdbModel', 'TmdbTask'].includes(suite) ? ['source/TmdbModel.brs'] : []),
    ...(suite === 'TmdbTask' ? ['components/TmdbTask.brs'] : []),
    ...(suite === 'VodShelfTask' ? ['components/VodShelfTask.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/AerioScene.brs'] : []),
    ...(suite === 'ConnectionNavigation' ? ['components/ConnectionNavigation.brs'] : []),
    ...(suite === 'ConnectionAuthTask' ? ['components/DispatcharrTask.brs'] : []),
    ...(suite === 'XtreamTask' ? ['components/XtreamTask.brs'] : []),
    ...(suite === 'StreamSourceTask' ? ['components/StreamSourceTask.brs'] : []),
    ...(suite === 'GuideMenu' ? ['components/GuideSettings.brs'] : []),
    ...(suite === 'LogoCache' ? ['components/LogoCacheTask.brs'] : []),
    ...(suite === 'VideoInput' ? ['components/AerioVideo.brs'] : []),
    ...(suite === 'GuideInput' ? ['components/GuideView.brs'] : []),
    ...(['GuideInput', 'GuideRemoteInput'].includes(suite) ? ['components/GuideRemoteInput.brs'] : []),
    ...(['PlayerLifecycle', 'PlayerRemoteInput'].includes(suite) ? ['components/PlayerRemoteInput.brs'] : []),
    ...(suite === 'GroupInput' ? ['components/GroupNavigator.brs'] : []),
    ...(['PlayerOkHold', 'PlayerLifecycle'].includes(suite) ? ['components/PlayerOptionsShortcut.brs'] : []),
    ...(['StartupRecovery', 'PlayerLifecycle'].includes(suite) ? ['components/StartupRecovery.brs'] : []),
    ...(suite === 'PlayerLifecycle' ? ['components/LiveRecovery.brs', 'components/PlaybackFailure.brs'] : []),
    ...(suite === 'PlayerLifecycle' ? ['components/MediaNavigation.brs', 'components/DvrPlayback.brs'] : []),
    ...(suite === 'DvrNavigation' ? ['components/MediaNavigation.brs', 'components/DvrNavigation.brs', 'components/DvrSeriesNavigation.brs', 'components/DvrPlayback.brs'] : []),
    ...(suite === 'DvrView' ? ['components/DvrView.brs'] : []),
    ...(suite === 'PlayerLifecycle' ? ['components/Diagnostics.brs'] : []),
    ...(suite === 'CatchupTask' ? ['components/CatchupTask.brs'] : []),
    ...(suite === 'OnDemandPlayer' ? ['components/OnDemandPlayer.brs'] : []),
    ...(suite === 'PlayerInfoClock' ? ['components/PlayerInfo.brs'] : []),
    ...(suite === 'ArchiveController' ? ['components/MediaNavigation.brs'] : []),
    ...(suite === 'VodSeriesLoader' ? ['source/VodSeriesLoader.brs'] : []),
    ...(suite === 'VodDescriptionInput' ? ['components/VodView.brs', 'components/VodMetadata.brs'] : []),
    ...(suite === 'LiveRecovery' ? ['components/LiveRecovery.brs'] : []),
    ...(suite === 'PlaybackFailure' ? ['components/PlaybackFailure.brs'] : []),
    ...(['AacStartup', 'PlayerLifecycle'].includes(suite) ? ['components/AacStartup.brs'] : []),
    ...(suite === 'CapabilityTask' ? ['components/CapabilityTask.brs'] : []),
    ...(suite === 'PlayerOptionsInput' ? ['components/PlayerOptions.brs'] : []),
    ...(suite === 'HttpPolicy' ? ['source/DispatcharrHttp.brs'] : []),
    ...(suite === 'GuideTaskCache' ? ['components/GuideTask.brs'] : []),
    ...(suite === 'GuideMappingFallback' ? ['components/GuideCache.brs'] : []),
    ...(suite === 'MappingTask' ? ['components/MappingTask.brs'] : []),
    `tests/${suite}.test.brs`,
  ], { encoding: 'utf8' });
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  if (result.error) throw result.error;
  if (result.status !== 0 || !result.stdout.includes('ALL TESTS PASSED')) {
    process.stderr.write(`Failed suite: ${suite}\n`);
    process.exit(1);
  }
}

const profileSuite = spawnSync(process.execPath, [
  'node_modules/brs/bin/cli.js', '--root', 'tests/unit-root',
  'source/DispatcharrModel.brs', 'source/ChannelProfileModel.brs',
  'tests/ChannelProfileModel.test.brs',
], { encoding: 'utf8' });
process.stdout.write(profileSuite.stdout ?? '');
process.stderr.write(profileSuite.stderr ?? '');
if (profileSuite.error) throw profileSuite.error;
if (profileSuite.status !== 0 || !profileSuite.stdout.includes('ALL TESTS PASSED')) {
  process.stderr.write('Failed suite: ChannelProfileModel\n');
  process.exit(1);
}

const profileTaskSuite = spawnSync(process.execPath, [
  'node_modules/brs/bin/cli.js', '--root', 'tests/unit-root',
  'source/DispatcharrModel.brs', 'source/ChannelProfileModel.brs', 'source/HttpPolicy.brs',
  'components/ProfileTask.brs', 'tests/ProfileTask.test.brs',
], { encoding: 'utf8' });
process.stdout.write(profileTaskSuite.stdout ?? '');
process.stderr.write(profileTaskSuite.stderr ?? '');
if (profileTaskSuite.error) throw profileTaskSuite.error;
if (profileTaskSuite.status !== 0 || !profileTaskSuite.stdout.includes('ALL TESTS PASSED')) {
  process.stderr.write('Failed suite: ProfileTask\n');
  process.exit(1);
}
