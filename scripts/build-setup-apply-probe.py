"""Build an isolated apply-controller probe: memory registry, fake provider Tasks."""
import importlib.util
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output):
    spec = importlib.util.spec_from_file_location('receiver_builder', ROOT / 'scripts/build-setup-receiver-probe.py')
    receiver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(receiver)
    output = Path(output)
    base = output.with_suffix('.receiver.zip')
    receiver.build(base, production_entropy=True)
    try:
        with zipfile.ZipFile(base) as original, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as package:
            for name in original.namelist():
                if name in ['source/Main.brs', 'components/SetupReceiverProbe.xml', 'components/SetupReceiverProbeScene.brs']:
                    continue
                package.writestr(name, original.read(name))
            package.write(ROOT / 'tests/native/SetupApplyProbeMain.brs', 'source/Main.brs')
            for name in ['DispatcharrModel', 'PreferenceModel', 'ConnectionStoreModel', 'MetadataCacheModel', 'M3uModel', 'XtreamModel', 'PhoneSetupApplyModel', 'PhoneSetupStore', 'TaskSupport']:
                package.write(ROOT / f'source/{name}.brs', f'source/{name}.brs')
            package.write(ROOT / 'components/PhoneSetupNavigation.brs', 'components/PhoneSetupNavigation.brs')
            for suffix in ['xml', 'brs']:
                package.write(ROOT / f'tests/native/SetupApplyProbe.{suffix}', f'components/SetupApplyProbe.{suffix}')
            package.write(ROOT / 'tests/native/SetupApplyFixtureTask.brs', 'components/SetupApplyFixtureTask.brs')
            cases = {}
            for case in ['reject', 'cancel', 'duplicate-cancel', 'duplicate-replace-full', 'duplicate-add', 'duplicate-full-add', 'm3u-query', 'xtream', 'default-profile']:
                playlist = {'type': 'dispatcharr', 'name': 'Received', 'url': 'HTTPS://EXAMPLE.TEST:443', 'userAgent': 'Fixture-Agent', 'credential': {'apiKey': 'fixture-api-key'}}
                if case == 'm3u-query':
                    playlist = {'type': 'm3u', 'name': 'Query', 'url': 'https://example.test/?token=session-token', 'userAgent': 'Fixture-Agent', 'guideDays': 3, 'vodEnabled': False}
                elif case in ['xtream', 'cancel']:
                    playlist = {'type': 'xtream', 'name': 'Xtream', 'url': 'https://example.test' + ('/slow' if case == 'cancel' else ''), 'userAgent': 'Fixture-Agent', 'credential': {'username': 'Viewer', 'password': 'fixture-password'}}
                elif case == 'reject':
                    playlist['url'] = 'https://example.test/reject'
                cases[case] = {'playlist': playlist}
                if case == 'default-profile':
                    del playlist['credential']
                    cases[case]['profiles'] = [{'username': 'Viewer', 'displayName': 'Viewer', 'isDefault': True, 'credential': {'apiKey': 'fixture-api-key'}, 'pinType': 'numbers', 'pinHash': 'ab' * 32, 'pinSalt': 'cd' * 16}]
            package.writestr('apply-cases.json', json.dumps(cases))
            common = {'cancelRequested': 'boolean', 'requestIdentity': 'assocarray', 'result': 'assocarray', 'progress': 'string',
                      'url': 'string', 'baseUrl': 'string', 'connectionId': 'string', 'apiKey': 'string',
                      'username': 'string', 'password': 'string', 'cacheEpoch': 'string', 'authMode': 'string', 'channelProfileIds': 'array'}
            for name, provider in [('M3uTask', 'm3u'), ('DispatcharrTask', 'dispatcharr'), ('XtreamTask', 'xtream')]:
                fields = ''.join(f'<field id="{field}" type="{kind}" alwaysNotify="true" />' for field, kind in common.items())
                package.writestr(f'components/{name}.xml', f'<component name="{name}" extends="Task"><interface>{fields}<field id="fixtureType" type="string" value="{provider}" /></interface><script type="text/brightscript" uri="pkg:/source/DispatcharrModel.brs" /><script type="text/brightscript" uri="SetupApplyFixtureTask.brs" /></component>')
    finally:
        base.unlink()
    return output


if __name__ == '__main__':
    print(build(ROOT / 'out/setup-apply-probe.zip'))
