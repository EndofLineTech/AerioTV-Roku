"""Build an isolated apply-controller probe: memory registry, fake provider Tasks."""
import importlib.util
import json
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent


def build(output, real_http=False):
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
            for name in ['DispatcharrModel', 'PreferenceModel', 'ConnectionStoreModel', 'MetadataCacheModel', 'M3uModel', 'XtreamModel', 'PhoneSetupApplyModel', 'PhoneSetupStore', 'TaskSupport', 'UserProfileModel', 'UserProfilePin', 'UserProfileAvatar', 'UserProfileStore', 'UserProfileLifecycle']:
                package.write(ROOT / f'source/{name}.brs', f'source/{name}.brs')
            package.write(ROOT / 'components/PhoneSetupNavigation.brs', 'components/PhoneSetupNavigation.brs')
            package.write(ROOT / 'components/UserProfileNavigation.brs', 'components/UserProfileNavigation.brs')
            for suffix in ['xml', 'brs']:
                source = (ROOT / f'tests/native/SetupApplyProbe.{suffix}').read_text()
                if suffix == 'xml':
                    scripts = ''.join(f'  <script type="text/brightscript" uri="pkg:/source/{name}.brs" />\n'
                                      for name in ['UserProfileModel', 'UserProfilePin', 'UserProfileAvatar', 'UserProfileStore', 'UserProfileLifecycle'])
                    scripts += '  <script type="text/brightscript" uri="UserProfileNavigation.brs" />\n'
                    source = source.replace('  <children>', scripts + '  <children>')
                if suffix == 'xml' and real_http:
                    marker = 'id="httpFixture" type="boolean" value="false"'
                    assert source.count(marker) == 1
                    source = source.replace(marker, 'id="httpFixture" type="boolean" value="true"')
                    source = source.replace('  <children>', '  <script type="text/brightscript" uri="pkg:/source/GuideModel.brs" />\n  <script type="text/brightscript" uri="pkg:/source/XmltvModel.brs" />\n  <children>')
                package.writestr(f'components/SetupApplyProbe.{suffix}', source)
            if not real_http:
                package.write(ROOT / 'tests/native/SetupApplyFixtureTask.brs', 'components/SetupApplyFixtureTask.brs')
            cases = {}
            for case in ['reject', 'cancel', 'duplicate-cancel', 'duplicate-replace-full', 'duplicate-add', 'duplicate-full-add', 'm3u-query', 'xtream', 'default-profile', 'dispatcharr-password', 'multiple-profiles', 'protected-default-pin', 'protected-default-child', 'duplicate-profile-recovery', 'duplicate-profile-recovery-direct']:
                playlist = {'type': 'dispatcharr', 'name': 'Received', 'url': 'HTTPS://EXAMPLE.TEST:443', 'userAgent': 'Fixture-Agent', 'credential': {'apiKey': 'fixture-api-key'}}
                if case == 'm3u-query':
                    playlist = {'type': 'm3u', 'name': 'Query', 'url': 'https://example.test/?token=session-token', 'userAgent': 'Fixture-Agent', 'guideDays': 3, 'vodEnabled': False}
                elif case in ['xtream', 'cancel']:
                    playlist = {'type': 'xtream', 'name': 'Xtream', 'url': 'https://example.test' + ('/slow' if case == 'cancel' else ''), 'userAgent': 'Fixture-Agent', 'credential': {'username': 'Viewer', 'password': 'fixture-password'}}
                elif case == 'reject':
                    playlist['url'] = 'https://example.test/reject'
                cases[case] = {'playlist': playlist}
                if case == 'dispatcharr-password':
                    playlist['credential'] = {'username': 'Viewer', 'password': 'fixture-password'}
                if case == 'default-profile':
                    del playlist['credential']
                    cases[case]['profiles'] = [{'username': 'Viewer', 'displayName': 'Viewer', 'isDefault': True, 'credential': {'apiKey': 'fixture-api-key'}}]
                    if real_http:
                        playlist['channelProfileIds'] = [3, 5]
                if case == 'multiple-profiles':
                    cases[case]['profiles'] = [
                        {'username': 'Viewer', 'displayName': 'Viewer', 'isDefault': True},
                        {'username': 'Ignored', 'displayName': 'Ignored', 'role': 'future-role', 'pinType': 'future-pin', 'credential': {'apiKey': 'must-never-authenticate'}},
                        {'username': 'Child', 'displayName': 'Child', 'role': 'child', 'pinType': 'numbers', 'pinHash': 'ab' * 32, 'pinSalt': 'cd' * 16},
                    ]
                if case.startswith('protected-default'):
                    entry = {'username': 'Viewer', 'displayName': 'Viewer', 'isDefault': False}
                    if case.endswith('pin'):
                        entry.update(pinType='numbers', pinHash='ab' * 32, pinSalt='cd' * 16)
                    else:
                        entry['role'] = 'child'
                    cases[case]['profiles'] = [entry]
            package.writestr('apply-cases.json', json.dumps(cases))
            common = {'cancelRequested': 'boolean', 'requestIdentity': 'assocarray', 'result': 'assocarray', 'progress': 'string',
                      'url': 'string', 'baseUrl': 'string', 'connectionId': 'string', 'apiKey': 'string',
                      'username': 'string', 'password': 'string', 'cacheEpoch': 'string', 'authMode': 'string', 'channelProfileIds': 'array'}
            if real_http:
                for name in ['M3uTask', 'DispatcharrTask', 'XtreamTask', 'GuideTask']:
                    relative = f'components/{name}.xml'
                    package.write(ROOT / relative, relative)
                    for script in ET.parse(ROOT / relative).findall('script'):
                        uri = script.attrib['uri']
                        relative = uri.removeprefix('pkg:/') if uri.startswith('pkg:/') else 'components/' + uri
                        if relative not in package.namelist():
                            if relative == 'source/MetadataCacheStore.brs':
                                source = (ROOT / relative).read_text()
                                assert source.count('"cachefs:/aeriotv-metadata-v1"') == 1
                                package.writestr(relative, source.replace('"cachefs:/aeriotv-metadata-v1"', '"tmp:/setup-apply-http-cache"'))
                            else:
                                package.write(ROOT / relative, relative)
                for suffix in ['xml', 'brs']:
                    package.write(ROOT / f'tests/native/SetupApplyFixtureHttpTask.{suffix}', f'components/SetupApplyFixtureHttpTask.{suffix}')
                responses = {
                    'user': {'id': 7, 'username': 'Viewer', 'api_key': 'fixture-api-key'},
                    'channels': [{'id': i, 'uuid': f'11111111-2222-3333-4444-{i:012d}', 'name': 'Synthetic', 'channel_number': i, 'tvg_id': key} for i, key in enumerate(['fixture.station', 'fixture.secondary', 'fixture.unselected'], 1)],
                    'profiles': [{'id': 3, 'channels': [1]}, {'id': 5, 'channels': [2]}],
                    'programs': [{'id': i, 'title': 'HTTP Fixture', 'tvg_id': key, 'start_time': '2023-11-14T22:15:00Z', 'end_time': '2023-11-14T23:15:00Z'} for i, key in enumerate(['fixture.station', 'outside.station'], 1)],
                    'xc_account': {'user_info': {'auth': 1, 'status': 'Active', 'allowed_output_formats': ['ts']}, 'server_info': {'timezone': 'UTC'}},
                    'xc_categories': [{'category_id': '1', 'category_name': 'Synthetic'}],
                    'xc_channels': [{'stream_id': 1, 'name': 'Synthetic', 'category_id': '1', 'epg_channel_id': 'fixture.station', 'num': 1}],
                }
                package.writestr('SetupApplyFixtureHttpResponses.json', json.dumps(responses))
                programmes = ''.join(f'<programme channel="{key}" start="20231114221500 +0000" stop="20231114231500 +0000"><title>HTTP Fixture</title></programme>' for key in ['fixture.station', 'outside.station'])
                package.writestr('SetupApplyFixtureGuide.xml', '<tv>' + programmes + '</tv>')
            else:
                for name, provider in [('M3uTask', 'm3u'), ('DispatcharrTask', 'dispatcharr'), ('XtreamTask', 'xtream')]:
                    fields = ''.join(f'<field id="{field}" type="{kind}" alwaysNotify="true" />' for field, kind in common.items())
                    package.writestr(f'components/{name}.xml', f'<component name="{name}" extends="Task"><interface>{fields}<field id="fixtureType" type="string" value="{provider}" /></interface><script type="text/brightscript" uri="pkg:/source/DispatcharrModel.brs" /><script type="text/brightscript" uri="SetupApplyFixtureTask.brs" /></component>')
    finally:
        base.unlink()
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--real-http', action='store_true', help='Use production provider/Guide Tasks against a Roku loopback fixture server')
    args = parser.parse_args()
    name = 'setup-apply-http-probe.zip' if args.real_http else 'setup-apply-probe.zip'
    print(build(ROOT / 'out' / name, real_http=args.real_http))
