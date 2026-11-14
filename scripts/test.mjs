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
suites.unshift('HttpTransport');
suites.unshift('StrictJson');
suites.unshift('UserProfilePin');
suites.unshift('UserProfileModel');
suites.unshift('UserProfileAvatar');
suites.unshift('UserProfileLifecycle');
suites.unshift('UserProfileForget');
suites.unshift('UserProfileNavigation');
suites.unshift('UserProfileRemoval');
suites.unshift('RequestGateModel');
suites.unshift('RequestGateOwnCredential');
suites.unshift('RequestGateTask');
suites.unshift('RequestGateNavigation');
suites.unshift('RequestGateRenderer');
suites.unshift('UserProfileScope');
suites.unshift('UserProfileScopeStore');
suites.unshift('UserProfilePreferenceNavigation');
suites.unshift('UserViewGuards');
suites.unshift('DispatcharrSyncKey');
suites.unshift('DispatcharrSyncReadTask');
suites.unshift('DispatcharrSyncRoster');
suites.unshift('DispatcharrSyncEnvelope');
suites.unshift('DispatcharrSyncMerge');
suites.unshift('DispatcharrSyncPullStore');
suites.unshift('UserProfilePinPolicy');
suites.unshift('ProfilePinNavigation');
suites.unshift('DirectionsPinPad');
suites.unshift('ProfileRosterNavigation');
suites.unshift('UserProfileRuntime');
suites.unshift('UserProfileCredential');
suites.unshift('UserProfileManagementPolicy');
suites.unshift('ProfileAdultPinNavigation');
suites.unshift('ProfileManagementNavigation');
suites.unshift('UserProfileSwitch');
suites.unshift('UserProfileChildAccess');
suites.unshift('UserProfileChildRejectedPrompt');
suites.unshift('UserProfileChildActivation');
suites.unshift('ProfileSwitchNavigation');
suites.unshift('SettingsChildModel');
suites.unshift('SettingsChildNavigation');
suites.unshift('ProfileSetupFence');
suites.unshift('UserProfileOwnSignIn');
suites.unshift('UserProfileChildOwnSignIn');
suites.unshift('ProfileOwnSignInNavigation');
suites.unshift('ProfileSetupCredentialNavigation');
suites.unshift('ProfileRefreshNavigation', 'DvrSettlementNavigation', 'SubmittedRecordingPermit');
suites.unshift('LineupHistoryReconciliation');
suites.unshift('GuideRefreshPreferences');
suites.unshift('GuideFavoriteRetention');
suites.unshift('ProfileChildUnavailableNavigation');
suites.unshift('ProfileChildRejectedNavigation');
suites.unshift('UserProfileAddressPolicy');
suites.unshift('UserProfileAddressStore');
suites.unshift('UserProfileDefaultReplacement');
suites.unshift('UserProfileLiveDefault');
suites.unshift('UserProfileStore');
suites.unshift('StartupBeaconModel');
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
    'source/StartupBeaconModel.brs',
    'source/RemoteMapModel.brs', 'source/PreferenceModel.brs',
    'components/RecentHistoryNavigation.brs',
    ...(suite === 'ConnectionAuthTask' ? ['source/ChannelProfileModel.brs'] : []),
    ...(['PhoneSetupStore', 'PhoneSetupApplyModel', 'PhoneSetupAutoAdd', 'PhoneSetupNavigation', 'ConnectionStore', 'ConnectionNavigation', 'PlayerLifecycle'].includes(suite) ? ['source/ConnectionStoreModel.brs'] : []),
    'source/CapabilityModel.brs',
    'source/ProgramSearchModel.brs',
    'source/VideoGeometry.brs',
    'source/GuideSettingsModel.brs',
    'source/ReminderModel.brs',
    ...(['TmdbTask', 'VodShelfTask', 'VodSeriesTask', 'XtreamTask', 'XtreamVodTask', 'ConnectionAuthTask'].includes(suite) ? [] : ['source/MetadataCacheModel.brs']),
    'source/HttpPolicy.brs',
    'source/RequestGateModel.brs', ...(suite === 'ProfileSetupCredentialNavigation' ? [] : ['source/RequestGateClient.brs']), 'source/RequestGateRenderer.brs',
    ...(['ProfileSetupCredentialNavigation', 'ConnectionNavigation', 'PlayerLifecycle'].includes(suite) ? ['components/ProfileSetupCredentialNavigation.brs'] : []),
    ...(['ProfileRefreshNavigation', 'PlayerLifecycle'].includes(suite) ? ['components/ProfileRefreshNavigation.brs'] : []),
    ...(suite === 'GuideRefreshPreferences' ? ['components/GuideSettings.brs'] : []),
    ...(['DvrSettlementNavigation', 'ConnectionNavigation', 'PlayerLifecycle'].includes(suite) ? ['components/DvrSettlementNavigation.brs'] : []),
    ...(suite === 'ConnectionNavigation' ? ['components/RequestGateNavigation.brs'] : []),
    ...(suite === 'RequestGateNavigation' ? ['components/RequestGateNavigation.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'RequestGateTask' ? ['components/RequestGateTask.brs'] : []),
    ...(suite === 'UserProfileScope' ? ['source/UserProfileScope.brs', 'source/UserProfileModel.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(['UserProfileScopeStore', 'UserProfilePreferenceNavigation'].includes(suite) ? ['source/StrictJson.brs', 'source/UserProfileScope.brs', 'source/UserProfileScopeStore.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfileAvatar.brs', 'source/UserProfilePin.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'UserProfilePreferenceNavigation' ? ['components/UserProfilePreferenceNavigation.brs'] : []),
    ...(suite === 'UserViewGuards' ? ['components/MediaNavigation.brs'] : []),
    ...(suite === 'DispatcharrSyncKey' ? ['source/DispatcharrSyncKey.brs'] : []),
    ...(['DispatcharrSyncReadTask', 'DispatcharrSyncEnvelope'].includes(suite) ? ['source/DispatcharrSyncKey.brs', 'source/DispatcharrSyncEnvelope.brs', 'source/DispatcharrSyncRoster.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs'] : []),
    ...(suite === 'DispatcharrSyncReadTask' ? ['components/DispatcharrSyncReadTask.brs'] : []),
    ...(suite === 'DispatcharrSyncRoster' ? ['source/DispatcharrSyncKey.brs', 'source/DispatcharrSyncRoster.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs'] : []),
    ...(['DispatcharrSyncMerge', 'DispatcharrSyncPullStore'].includes(suite) ? ['source/DispatcharrSyncKey.brs', 'source/DispatcharrSyncRoster.brs', 'source/DispatcharrSyncMerge.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'DispatcharrSyncPullStore' ? ['source/DispatcharrSyncPullStore.brs', 'source/UserProfileScope.brs', 'source/StrictJson.brs'] : []),
    ...(suite === 'UserProfilePinPolicy' ? ['source/UserProfilePinPolicy.brs', 'source/UserProfilePin.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'ProfilePinNavigation' ? ['source/UserProfilePin.brs', 'components/ProfilePinNavigation.brs'] : []),
    ...(suite === 'DirectionsPinPad' ? ['components/DirectionsPinPad.brs'] : []),
    ...(suite === 'ProfileRosterNavigation' ? ['source/UserProfileScope.brs', 'components/ProfileRosterNavigation.brs'] : []),
    ...(suite === 'UserProfileRuntime' ? ['source/UserProfileRuntime.brs'] : []),
    ...(['UserProfileCredential', 'ConnectionNavigation', 'PlayerLifecycle'].includes(suite) ? ['source/UserProfileCredential.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs'] : []),
    ...(suite === 'UserProfileCredential' ? ['source/ConnectionStoreModel.brs'] : []),
    ...(['UserProfileManagementPolicy', 'ProfileAdultPinNavigation', 'ProfileManagementNavigation', 'UserProfileSwitch', 'UserProfileOwnSignIn', 'UserProfileChildOwnSignIn'].includes(suite) ? ['source/UserProfileManagementPolicy.brs', 'source/UserProfilePinPolicy.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(['UserProfileOwnSignIn', 'UserProfileChildOwnSignIn'].includes(suite) ? ['source/UserProfileOwnSignIn.brs', 'source/UserProfileAddressPolicy.brs', 'source/StrictJson.brs'] : []),
    ...(suite === 'UserProfileAddressPolicy' ? ['source/UserProfileAddressPolicy.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'UserProfileAddressStore' ? ['source/UserProfileAddressStore.brs', 'source/UserProfileAddressPolicy.brs', 'source/UserProfileScope.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'UserProfileDefaultReplacement' ? ['source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'UserProfileLiveDefault' ? ['source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs', 'source/UserProfileAddressPolicy.brs', 'source/UserProfileOwnSignIn.brs'] : []),
    ...(suite === 'UserProfileNavigation' ? ['source/UserProfileScope.brs'] : []),
    ...(suite === 'ProfileOwnSignInNavigation' ? ['components/ProfileOwnSignInNavigation.brs', 'components/SettingsNavigation.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/UserProfileScope.brs', 'source/UserProfileSwitch.brs', 'source/UserProfileOwnSignIn.brs', 'source/UserProfileAddressPolicy.brs', 'source/StrictJson.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'ProfileChildUnavailableNavigation' ? ['components/ProfileChildUnavailableNavigation.brs', 'source/UserProfileAddressPolicy.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/UserProfileCredential.brs', 'source/UserProfileChildAccess.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'ProfileChildRejectedNavigation' ? ['components/ProfileChildRejectedNavigation.brs', 'source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileChildAccess.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'UserProfileSwitch' ? ['source/UserProfileSwitch.brs', 'source/UserProfileAddressPolicy.brs', 'source/UserProfileScope.brs', 'source/StrictJson.brs'] : []),
    ...(['UserProfileChildAccess', 'UserProfileChildRejectedPrompt'].includes(suite) ? ['source/UserProfileChildAccess.brs', 'source/UserProfileStore.brs', 'source/UserProfileModel.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'UserProfileChildActivation' ? ['source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'ProfileSwitchNavigation' ? ['components/ProfileSwitchNavigation.brs', 'source/UserProfileScope.brs', 'source/UserProfileModel.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(suite === 'SettingsChildModel' ? ['source/SettingsModel.brs'] : []),
    ...(suite === 'SettingsChildNavigation' ? ['source/SettingsModel.brs', 'components/SettingsNavigation.brs'] : []),
    ...(['ProfileAdultPinNavigation', 'ProfileManagementNavigation'].includes(suite) ? ['components/ProfileAdultPinNavigation.brs'] : []),
    ...(suite === 'ProfileManagementNavigation' ? ['components/ProfileManagementNavigation.brs'] : []),
    ...(suite === 'HttpTransport' ? ['source/HttpTransport.brs'] : []),
    ...(suite === 'StrictJson' ? ['source/StrictJson.brs'] : []),
    ...(['PreferenceModel', 'LineupHistoryReconciliation', 'PlayerLifecycle', 'ConnectionNavigation', 'UserProfileNavigation', 'ProfileSetupFence', 'PhoneSetupNavigation', 'PhoneSetupAutoAdd'].includes(suite) ? ['source/StrictJson.brs'] : []),
    ...(suite === 'UserProfilePin' ? ['source/UserProfilePin.brs'] : []),
    ...(['UserProfileModel', 'UserProfileStore', 'UserProfileLifecycle', 'UserProfileForget', 'UserProfileNavigation', 'UserProfileRemoval'].includes(suite) ? ['source/UserProfileModel.brs'] : []),
    ...(suite === 'UserProfileAvatar' ? ['source/UserProfileAvatar.brs'] : []),
    ...(['UserProfileStore', 'UserProfileLifecycle', 'UserProfileForget', 'UserProfileNavigation', 'UserProfileRemoval'].includes(suite) ? ['source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs', 'source/ConnectionStoreModel.brs'] : []),
    ...(['UserProfileForget', 'UserProfileRemoval'].includes(suite) ? ['source/UserProfileCleanup.brs', 'source/StrictJson.brs'] : []),
    ...(['UserProfileNavigation', 'ProfileSetupFence', 'ConnectionNavigation', 'PlayerLifecycle', 'PhoneSetupNavigation', 'PhoneSetupAutoAdd'].includes(suite) ? ['components/UserProfileNavigation.brs', 'source/UserProfileAddressPolicy.brs'] : []),
    ...(['ProfileSetupFence', 'PhoneSetupNavigation', 'PhoneSetupAutoAdd'].includes(suite) ? ['source/UserProfileModel.brs', 'source/UserProfileStore.brs', 'source/UserProfileLifecycle.brs', 'source/UserProfilePin.brs', 'source/UserProfileAvatar.brs'] : []),
    ...(suite === 'ProfileSetupFence' ? ['components/ConnectionNavigation.brs', 'components/PhoneSetupNavigation.brs', 'source/ConnectionStoreModel.brs'] : []),
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
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/SettingsNavigation.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/ProfileRosterNavigation.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/ProfileAdultPinNavigation.brs', 'components/ProfileManagementNavigation.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/ProfileSwitchNavigation.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/ProfileChildUnavailableNavigation.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/ProfileChildRejectedNavigation.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['source/UserProfileChildAccess.brs'] : []),
    ...(['PlayerLifecycle', 'ConnectionNavigation'].includes(suite) ? ['components/ProfileOwnSignInNavigation.brs'] : []),
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

const pairingBuild = spawnSync('python3', ['-m', 'unittest', 'scripts/pairing_test_build_test.py', 'scripts/ui_library_audit_test.py', 'scripts/ui_assets_test.py', 'scripts/profile_probe_test.py'], { encoding: 'utf8' });
process.stdout.write(pairingBuild.stdout ?? '');
process.stderr.write(pairingBuild.stderr ?? '');
if (pairingBuild.error) throw pairingBuild.error;
if (pairingBuild.status !== 0) process.exit(1);
