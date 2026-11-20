import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { Writable } from 'node:stream';
import { test } from 'node:test';
import { gzipSync, gunzipSync } from 'node:zlib';

const require = createRequire(import.meta.url);
const brs = require('brs');
const { Interpreter } = require('brs/lib/interpreter');
const { BrsObjects } = require('brs/lib/brsTypes/components/BrsObjects');
const { BrsBoolean, Callable, Int32, RoArray, StdlibArgument, ValueKind } = brs.types;

const playlist = '#EXTM3U\n#EXTINF:-1 tvg-id="station.alpha",Fixture News\nhttps://example.test/live.ts\n';
const guide = '<?xml version="1.0"?><tv><channel id="station.alpha"><display-name>Fixture News</display-name></channel>'
  + '<programme start="20260923183000 +0000" stop="20260923190000 +0000" channel="station.alpha">'
  + '<title>Fixture News</title></programme></tv>';
const staged = new Map();

for (const [extension, text] of [['m3u', playlist], ['xml', guide]]) {
  const plain = Buffer.from(text);
  const compressed = gzipSync(plain);
  // Same wire bytes, different response semantics. Only the HTTP-encoded
  // representation models a transport handing decoded bytes to the app.
  for (const [path, wire, contentEncoding] of [
    [`${extension}-raw`, compressed, 'identity'],
    [`${extension}-http`, compressed, 'gzip'],
    [`plain.${extension}.gz`, plain, 'identity'],
  ]) {
    staged.set(path, contentEncoding === 'gzip' ? gunzipSync(wire) : wire);
  }
}

test('direct feed parsers distinguish staged raw gzip from text, independently of file name', () => {
  // The host interpreter lacks roByteArray. Stub only the bounded staged
  // read; do not emulate roUrlTransfer or claim native HTTP behavior.
  BrsObjects.set('robytearray', () => {
    const bytes = new RoArray([]);
    bytes.appendMethod('readFile', new Callable('readFile', {
      signature: {
        args: [
          new StdlibArgument('path', ValueKind.String),
          new StdlibArgument('offset', ValueKind.Int32),
          new StdlibArgument('length', ValueKind.Int32),
        ],
        returns: ValueKind.Boolean,
      },
      impl: (_interpreter, path, offset, length) => {
        const file = staged.get(path.value);
        assert.equal(offset.getValue(), 0);
        assert.equal(length.getValue(), path.value.includes('m3u') ? 2 : 16);
        if (!file) return BrsBoolean.False;
        bytes.elements = Array.from(file.subarray(0, length.getValue()), value => new Int32(value));
        return BrsBoolean.True;
      },
    }));
    return bytes;
  });
  let output = '';
  let errors = '';
  const stdout = new Writable({ write(chunk, _encoding, done) { output += chunk; done(); } });
  const stderr = new Writable({ write(chunk, _encoding, done) { errors += chunk; done(); } });
  try {
    const options = { root: 'tests/unit-root', stdout, stderr, generateCoverage: false };
    const statements = brs.lexParseSync([
      'source/DispatcharrModel.brs', 'source/GuideModel.brs', 'source/M3uModel.brs',
      'source/XmltvModel.brs', 'components/M3uTask.brs', 'tests/DirectFeedGzip.test.brs',
    ], options);
    const interpreter = new Interpreter(options);
    interpreter.onError(error => { errors += String(error.message); });
    interpreter.exec(statements, ...['m3u-http', 'plain.m3u.gz', 'xml-http', 'plain.xml.gz']
      .map(path => new brs.types.BrsString(staged.get(path).toString('utf8'))));
    assert.equal(errors, '');
    assert.match(output, /ALL TESTS PASSED/, output);
  } finally {
    BrsObjects.delete('robytearray');
  }
});
