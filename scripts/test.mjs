import { spawnSync } from 'node:child_process';

const suites = ['DispatcharrModel', 'GuideModel', 'XmltvModel', 'M3uModel', 'XtreamModel', 'XtreamVodModel', 'XtreamArchiveModel', 'XtreamTask', 'XtreamVodTask', 'SceneUi', 'AerioSurface', 'RemoteHints', 'TaskSupport', 'PlaybackModel', 'NowNextModel', 'PreferenceModel', 'ConnectionStore', 'ConnectionNavigation', 'ConnectionAuthTask', 'CapabilityModel', 'ProgramSearchModel', 'GuideUnifiedSearch', 'PlayerLifecycle', 'VideoGeometry', 'StreamSourceTask', 'GuideSettingsModel', 'ReminderModel', 'GuideMenu', 'LogoCache', 'VideoInput', 'GuideInput', 'GroupInput', 'PlayerOkHold', 'PlayerRemoteInput', 'GuideRemoteInput', 'StartupRecovery', 'AacStartup', 'CapabilityTask', 'PlayerOptionsInput', 'MetadataCacheModel', 'HttpPolicy', 'DvrRecordingModel', 'DvrPresentationModel', 'DvrNavigation', 'DvrView', 'GuideTaskCache', 'GuideMappingFallback', 'MappingTask', 'MappingDetailModel', 'LiveRecovery', 'PlaybackFailure', 'MediaSessionModel', 'VodModel', 'VodState', 'VodSeriesTarget', 'VodSeriesTask', 'CatchupModel', 'DiagnosticModel', 'OnDemandPlayer', 'RecordingSeekModel', 'ArchiveController', 'VodSeriesLoader', 'NavigationModel', 'DescriptionModel', 'VodDescriptionInput', 'SettingsModel', 'PlayerInfoClock', 'TmdbModel', 'TmdbTask', 'VodShelfTask', 'RemoteMapModel', 'SettingsRail', 'SettingsHubInput'];
suites.unshift('LaunchModel');
suites.unshift('PhoneSetupModel');
suites.unshift('PhoneSetupTransport');
suites.unshift('PhoneSetupMdns');
suites.unshift('PhoneSetupApplyModel');
suites.unshift('PhoneSetupCancellation');
suites.unshift('PhoneSetupStore');
suites.unshift('PhoneSetupNavigation');
suites.unshift('PhoneSetupAutoAdd');
suites.unshift('PillListItem');
suites.unshift('GuideEmptyState');
suites.unshift('UiAuditLibraryData');
suites.unshift('UiAuditFixtureTask');
suites.unshift('RecentHistory');
suites.unshift('GuideHistory', 'BrowserHistory');
suites.unshift('RokuAuthModel');
suites.splice(suites.indexOf('GuideUnifiedSearch'), 0, 'ProgramSearchView');
for (const suite of suites) {
  const result = spawnSync(process.execPath, [
    'node_modules/brs/bin/cli.js', '--root', 'tests/unit-root',
    'source/DispatcharrModel.brs', 'source/GuideModel.brs', 'source/SceneUi.brs', 'source/TaskSupport.brs',
    ...(suite === 'LaunchModel' ? ['source/LaunchModel.brs'] : []),
    ...(suite === 'PillListItem' ? ['components/AerioPillListItem.brs'] : []),
    ...(suite === 'GuideEmptyState' ? ['components/GuideView.brs'] : []),
    ...(suite === 'UiAuditLibraryData' ? ['tests/native/UiAuditLibraryData.brs', 'tests/native/UiAuditGuideData.brs'] : []),
    ...(suite === 'UiAuditFixtureTask' ? ['tests/native/UiAuditLibraryData.brs', 'tests/native/UiAuditFixtureTask.brs'] : []),
    ...(suite === 'PhoneSetupModel' ? ['source/PhoneSetupModel.brs'] : []),
    ...(suite === 'PhoneSetupApplyModel' ? ['source/PhoneSetupModel.brs', 'source/PhoneSetupApplyModel.brs'] : []),
    ...(suite === 'PhoneSetupCancellation' ? ['components/PhoneSetupTask.brs'] : []),
    ...(suite === 'PhoneSetupMdns' ? ['source/PhoneSetupMdns.brs'] : []),
    ...(suite === 'PhoneSetupStore' ? ['source/PhoneSetupStore.brs'] : []),
    ...(['PhoneSetupNavigation', 'PhoneSetupAutoAdd'].includes(suite) ? ['source/PhoneSetupModel.brs', 'source/PhoneSetupApplyModel.brs', 'components/PhoneSetupNavigation.brs'] : []),
    ...(suite === 'PhoneSetupAutoAdd' ? ['source/PhoneSetupStore.brs'] : []),
    ...(suite === 'PhoneSetupTransport' ? ['source/PhoneSetupModel.brs', 'source/PhoneSetupTransport.brs', 'source/PhoneSetupLink.brs'] : []),
    ...(suite === 'GuideHistory' ? ['components/GuideView.brs', 'components/GuideSettings.brs'] : []),
    ...(suite === 'BrowserHistory' ? ['components/ChannelBrowser.brs'] : []),
    ...(suite === 'RokuAuthModel' ? ['source/RokuAuthModel.brs'] : []),
    ...(suite === 'XmltvModel' ? ['source/XmltvModel.brs'] : []),
    ...(['PhoneSetupApplyModel', 'M3uModel', 'PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['source/M3uModel.brs'] : []),
    ...(['PhoneSetupApplyModel', 'XtreamModel', 'XtreamVodModel', 'XtreamArchiveModel', 'XtreamTask', 'XtreamVodTask', 'PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['source/XtreamModel.brs'] : []),
    ...(['XtreamArchiveModel', 'PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['source/XtreamArchiveModel.brs'] : []),
    ...(['XtreamVodModel', 'XtreamVodTask', 'XtreamTask', 'PlayerLifecycle'].includes(suite) ? ['source/XtreamVodModel.brs'] : []),
    'source/PlaybackModel.brs',
    ...(suite === 'RemoteHints' ? ['components/RemoteHints.brs'] : []),
    ...(suite === 'AerioSurface' ? ['components/AerioSurface.brs'] : []),
    'source/NowNextModel.brs',
    'source/RemoteMapModel.brs', 'source/PreferenceModel.brs',
    'components/RecentHistoryNavigation.brs',
    ...(suite === 'ConnectionAuthTask' ? ['source/ChannelProfileModel.brs'] : []),
    ...(['PhoneSetupStore', 'PhoneSetupApplyModel', 'PhoneSetupAutoAdd', 'ConnectionStore', 'ConnectionNavigation', 'PlayerLifecycle'].includes(suite) ? ['source/ConnectionStoreModel.brs'] : []),
    'source/CapabilityModel.brs',
    'source/ProgramSearchModel.brs',
    'source/VideoGeometry.brs',
    'source/GuideSettingsModel.brs',
    'source/ReminderModel.brs',
    ...(['TmdbTask', 'VodShelfTask', 'VodSeriesTask', 'XtreamTask', 'XtreamVodTask', 'ConnectionAuthTask'].includes(suite) ? [] : ['source/MetadataCacheModel.brs']),
    'source/HttpPolicy.brs',
    ...(suite === 'DvrRecordingModel' ? ['source/DvrRecordingModel.brs'] : []),
    ...(suite === 'DvrRecordingModel' ? ['source/DvrSeriesModel.brs'] : []),
    ...(['DvrPresentationModel', 'DvrNavigation', 'DvrHandoff', 'DvrView'].includes(suite) ? ['source/DvrPresentationModel.brs'] : []),
    'source/MediaSessionModel.brs', 'source/VodModel.brs', 'source/VodState.brs',
    ...(['VodSeriesTarget', 'VodSeriesTask', 'VodShelfTask'].includes(suite) ? ['source/VodSeriesTarget.brs'] : []), 'source/CatchupModel.brs',
    ...(['RecordingSeekModel', 'OnDemandPlayer'].includes(suite) ? ['source/RecordingSeekModel.brs'] : []),
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
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/PhoneSetupNavigation.brs'] : []),
    ...(suite === 'ConnectionNavigation' ? ['components/ConnectionNavigation.brs'] : []),
    ...(suite === 'ConnectionAuthTask' ? ['components/DispatcharrTask.brs'] : []),
    ...(suite === 'XtreamTask' ? ['components/XtreamTask.brs'] : []),
    ...(suite === 'XtreamVodTask' ? ['components/XtreamVodTask.brs'] : []),
    ...(suite === 'StreamSourceTask' ? ['components/StreamSourceTask.brs'] : []),
    ...(suite === 'GuideMenu' ? ['components/GuideSettings.brs'] : []),
    ...(suite === 'GuideUnifiedSearch' ? ['components/GuideView.brs', 'components/GuideUnifiedSearch.brs'] : []),
    ...(suite === 'ProgramSearchView' ? ['components/ProgramSearchView.brs'] : []),
    ...(suite === 'LogoCache' ? ['components/LogoCacheTask.brs', 'components/GuideLogos.brs'] : []),
    ...(suite === 'VideoInput' ? ['components/AerioVideo.brs'] : []),
    ...(suite === 'GuideInput' ? ['components/GuideView.brs'] : []),
    ...(['GuideInput', 'GuideRemoteInput'].includes(suite) ? ['components/GuideRemoteInput.brs'] : []),
    ...(['PlayerLifecycle', 'PlayerRemoteInput'].includes(suite) ? ['components/PlayerRemoteInput.brs'] : []),
    ...(suite === 'GroupInput' ? ['components/GroupNavigator.brs'] : []),
    ...(['PlayerOkHold', 'PlayerLifecycle'].includes(suite) ? ['components/PlayerOptionsShortcut.brs'] : []),
    ...(['StartupRecovery', 'PlayerLifecycle'].includes(suite) ? ['components/StartupRecovery.brs'] : []),
    ...(suite === 'PlayerLifecycle' ? ['components/HlsSessionLifecycle.brs', 'components/LiveRecovery.brs', 'components/PlaybackFailure.brs'] : []),
    ...(['PlayerLifecycle', 'DvrHandoff'].includes(suite) ? ['components/MediaNavigation.brs', 'components/DvrPlayback.brs'] : []),
    ...(suite === 'DvrNavigation' ? ['components/MediaNavigation.brs', 'components/DvrNavigation.brs', 'components/DvrSeriesNavigation.brs', 'components/DvrPlayback.brs'] : []),
    ...(suite === 'DvrView' ? ['components/DvrView.brs'] : []),
    ...(suite === 'PlayerLifecycle' ? ['components/Diagnostics.brs'] : []),
    ...(suite === 'CatchupTask' ? ['components/CatchupTask.brs'] : []),
    ...(suite === 'OnDemandPlayer' ? ['components/OnDemandPlayer.brs'] : []),
    ...(suite === 'PlayerInfoClock' ? ['components/PlayerInfo.brs'] : []),
    ...(suite === 'ArchiveController' ? ['components/MediaNavigation.brs'] : []),
    ...(['VodSeriesLoader', 'VodSeriesTask', 'VodShelfTask'].includes(suite) ? ['source/VodSeriesLoader.brs'] : []),
    ...(suite === 'VodSeriesTask' ? ['components/VodTask.brs'] : []),
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
    ...(suite === 'MappingDetailModel' ? ['components/MappingDetailFetch.brs'] : []),
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

// Synthetic crypto arithmetic and fake installer/console regression tests only.
// These commands never connect to a Roku or install a development package.
for (const args of [
  ['scripts/test-setup-qr.mjs'],
  ['--test', 'scripts/setup-receiver-isolation.test.mjs', 'scripts/channel-logo-isolation.test.mjs', 'scripts/ui-audit-isolation.test.mjs'],
  ['scripts/test-setup-x25519.mjs'],
  ['--test', 'scripts/validate-phone-setup-native.test.mjs'],
]) {
  const result = spawnSync(process.execPath, args, { encoding: 'utf8', timeout: 600000 });
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(1);
}

const pairingBuild = spawnSync('python3', ['-m', 'unittest', 'scripts/pairing_test_build_test.py', 'scripts/ui_library_audit_test.py', 'scripts/ui_assets_test.py'], { encoding: 'utf8' });
process.stdout.write(pairingBuild.stdout ?? '');
process.stderr.write(pairingBuild.stderr ?? '');
if (pairingBuild.error) throw pairingBuild.error;
if (pairingBuild.status !== 0) process.exit(1);
