import { spawnSync } from 'node:child_process';

for (const suite of ['DispatcharrModel', 'GuideModel', 'SceneUi', 'TaskSupport', 'PlaybackModel', 'NowNextModel', 'PreferenceModel', 'CapabilityModel', 'ProgramSearchModel', 'PlayerLifecycle', 'VideoGeometry', 'StreamSourceTask']) {
  const result = spawnSync(process.execPath, [
    'node_modules/brs/bin/cli.js', '--root', 'tests',
    'source/DispatcharrModel.brs', 'source/GuideModel.brs', 'source/SceneUi.brs', 'source/TaskSupport.brs',
    'source/PlaybackModel.brs',
    'source/NowNextModel.brs',
    'source/PreferenceModel.brs',
    'source/CapabilityModel.brs',
    'source/ProgramSearchModel.brs',
    'source/VideoGeometry.brs',
    ...(suite === 'PlayerLifecycle' ? ['components/AerioScene.brs'] : []),
    ...(suite === 'StreamSourceTask' ? ['components/StreamSourceTask.brs'] : []),
    `tests/${suite}.test.brs`,
  ], { encoding: 'utf8' });
  process.stdout.write(result.stdout ?? '');
  process.stderr.write(result.stderr ?? '');
  if (result.error) throw result.error;
  if (result.status !== 0 || !result.stdout.includes('ALL TESTS PASSED')) process.exit(1);
}
