import assert from 'node:assert/strict';
import test from 'node:test';
import { assertNumericGuardNativeVerdict, checkNumericGuardReport, numericGuardInventory } from './numeric-guard-report.mjs';

const prefix = '[numeric-guard]';

function fixture(native = false) {
  const rows = [...numericGuardInventory(native).values()].map(spec => {
    const kinds = spec.kinds.map(options => options[0]);
    const observed = typeof spec.expected === 'function';
    return {
      target: spec.target, name: spec.name, kinds: kinds.join('/'), lane: spec.lane,
      expected: observed ? 'observe' : spec.expected,
      actual: observed ? spec.expected(kinds)[0] : spec.expected,
    };
  });
  const summary = {
    native, rows: rows.length, mismatches: 0, callermismatches: 0, callershapemismatches: 0,
    observations: rows.filter(row => row.expected === 'observe').length,
  };
  return { rows, summary };
}

function lines({ rows, summary }) {
  return [
    'Running dev',
    `${prefix} PRIMITIVES {"one":"Integer","fetched":"Integer"}`,
    ...rows.map(row => `${prefix} ${JSON.stringify(row)}`),
    `${prefix} COMPLETE ${JSON.stringify(summary)}`,
  ];
}

const report = sample => lines(sample).join('\n');
const find = (sample, target, name) => sample.rows.find(row => row.target === target && row.name === name);

function postFixFixture() {
  const sample = fixture(true);
  for (const [name, kinds] of [
    ['primitive-assigned/schema', 'roInteger/Integer/Integer'],
    ['primitive-assigned/fetched', 'Integer/roInteger/Integer'],
    ['constructed-envelope', 'roInteger/roInteger/Integer'],
    ['aa-int/schema', 'roInteger/Integer/Integer'],
    ['aa-int/fetched', 'Integer/roInteger/Integer'],
  ]) Object.assign(find(sample, 'metadata/state', name), { kinds, actual: 'miss' });
  for (const name of ['primitive-assigned', 'aa-int']) {
    Object.assign(find(sample, 'preferences/model', name), { kinds: 'roInteger', actual: 'default' });
  }
  for (const [name, kinds] of [
    ['aa-int/response', 'roInteger/Integer'],
    ['aa-int/cap', 'Integer/roInteger'],
    ['transport-aa-shape', 'roInteger/Integer'],
    ['task-cap-shape', 'Integer/roInteger'],
    ['native-byte-array-count', 'roInteger/Integer'],
  ]) find(sample, 'http/failure', name).kinds = kinds;
  sample.summary.mismatches = 7;
  return sample;
}

test('recognizes the separate exact host and native inventories', () => {
  for (const [native, rows, observations] of [[false, 210, 18], [true, 231, 14]]) {
    const sample = fixture(native);
    const result = checkNumericGuardReport(report(sample), native);
    assert.equal(result.summary.rows, rows);
    assert.equal(result.summary.observations, observations);
    assert.deepEqual(result.mismatches, []);
    assert.throws(() => checkNumericGuardReport(report(sample), !native), /[Cc]ase|[Ll]ane|[Kk]inds/);
  }
});

test('rejects a full-sized unique impostor, duplicates and missing cases even with adjusted counts', () => {
  const native = fixture(true);
  native.rows.at(-1).name = 'an-invented-case';
  assert.throws(() => checkNumericGuardReport(report(native), true), /Unexpected case/);
  const host = fixture();
  host.rows[0] = host.rows[1];
  assert.throws(() => checkNumericGuardReport(report(host), false), /Duplicate case/);
  host.rows.shift();
  host.rows.pop();
  host.summary.rows -= 2;
  assert.throws(() => checkNumericGuardReport(report(host), false), /Missing cases/);
});

test('rejects report-controlled expectations and relabeling even with internally consistent totals', () => {
  const sample = fixture(true);
  const row = find(sample, 'metadata/state', 'epoch-roundtrip');
  row.actual = row.expected = 'miss';
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Wrong expectation/);
  row.expected = 'observe';
  sample.summary.observations++;
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Wrong expectation/);
  row.expected = 'fresh';
  row.lane = 'synthetic';
  sample.summary.observations--;
  sample.summary.mismatches++;
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Wrong lane/);
});

test('checks slot count, allowed kind per input, primitive control and scalar fields', () => {
  const sample = fixture(true);
  const row = find(sample, 'metadata/state', 'fetched-at-now');
  for (const kinds of ['Integer/Integer', 'Integer/Integer/roLongInteger', 'Integer/Integer/roInteger', 'roInvalid/Integer/Integer']) {
    row.kinds = kinds;
    assert.throws(() => checkNumericGuardReport(report(sample), true), /Invalid kinds/);
  }
  row.kinds = 'roInt/roInteger/Integer';
  assert.doesNotThrow(() => checkNumericGuardReport(report(sample), true));
  row.actual = true;
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Non-string/);
  row.actual = 'fresh';
  row.unexpected = 'field';
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Invalid case fields/);
  delete row.unexpected;
  const log = lines(sample);
  const duplicate = log[2].replace('{', '{"actual":"other",');
  assert.throws(() => checkNumericGuardReport([log[0], log[1], duplicate, ...log.slice(3)].join('\n'), true),
    /Duplicate or nested case fields/);
  log[1] = `${prefix} PRIMITIVES {"one":"String","fetched":"Integer"}`;
  assert.throws(() => checkNumericGuardReport(log.join('\n'), true), /Invalid primitive control type/);
});

test('parser observations are kind-specific and cannot hide error outcomes or console errors', () => {
  const sample = fixture(true);
  const row = find(sample, 'http/failure', 'parsed-decimal-whole/response');
  row.kinds = 'roDouble/Integer';
  row.actual = '';
  assert.doesNotThrow(() => checkNumericGuardReport(report(sample), true));
  for (const actual of ['at-least-1-mib', 'at-least-16-mb', 'host-fix-unsupported', 'something-else']) {
    row.actual = actual;
    assert.throws(() => checkNumericGuardReport(report(sample), true), /Unexpected observation/);
  }
  for (const actual of ['bad-category', 'fixture-error', 'runtime-exception', 'bad-result']) {
    row.actual = actual;
    assert.throws(() => checkNumericGuardReport(report(sample), true), /Fixture or runtime error/);
  }
  row.actual = '';
  assert.throws(() => checkNumericGuardReport(`${report(sample)}\nRuntime Error &h02`, true), /Probe console error/);
  assert.throws(() => checkNumericGuardReport(`${report(sample)}\nERROR compiling file`, true), /Probe console error/);
  const unsupported = fixture();
  find(unsupported, 'phone/payload/guideDays', 'typed-double-whole').actual = 'accepted';
  assert.throws(() => checkNumericGuardReport(report(unsupported), false), /Unexpected observation/);
});

test('rejects malformed or incomplete streams and bogus summary values', () => {
  const sample = fixture();
  const log = lines(sample);
  assert.throws(() => checkNumericGuardReport(log.slice(0, -1).join('\n'), false), /Missing terminal/);
  assert.throws(() => checkNumericGuardReport(log.filter(line => !line.includes('PRIMITIVES')).join('\n'), false), /Missing primitive/);
  assert.throws(() => checkNumericGuardReport([...log, log[2]].join('\n'), false), /after terminal/);
  assert.throws(() => checkNumericGuardReport([...log.slice(0, -1), `${prefix} malformed`, log.at(-1)].join('\n'), false), SyntaxError);
  sample.summary.rows = '210';
  assert.throws(() => checkNumericGuardReport(report(sample), false), /Wrong terminal summary/);
  sample.summary.rows = 210;
  sample.summary.native = true;
  assert.throws(() => checkNumericGuardReport(report(sample), false), /Wrong terminal summary/);
});

test('native mismatch accounting keeps caller, caller-shape and other cases separate', () => {
  const sample = fixture(true);
  find(sample, 'metadata/state', 'epoch-roundtrip').actual = 'miss';
  find(sample, 'http/failure', 'task-cap-shape').actual = '';
  find(sample, 'http/failure', 'aa-int/cap').actual = '';
  Object.assign(sample.summary, { mismatches: 3, callermismatches: 1, callershapemismatches: 1 });
  const result = checkNumericGuardReport(report(sample), true);
  assert.deepEqual(result.mismatches.map(row => row.lane).sort(), ['caller', 'caller-shape', 'synthetic']);
  sample.summary.callermismatches = 2;
  sample.summary.callershapemismatches = 0;
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Wrong terminal summary/);
});

test('native boxing aliases are confined to the observed AA input slots', () => {
  const sample = fixture(true);
  find(sample, 'http/failure', 'double-whole/response').kinds = 'roFloat/Integer';
  find(sample, 'metadata/state', 'double-fractional/fetched').kinds = 'Integer/roFloat/Integer';
  find(sample, 'preferences/model', 'double-whole').kinds = 'roFloat';
  find(sample, 'phone/payload/guideDays', 'typed-double-whole').kinds = 'roFloat';
  for (const field of ['guideDays', 'catchupOffsetMinutes', 'channelProfileIds']) {
    find(sample, `phone/payload/${field}`, 'typed-invalid').kinds = 'roInvalid';
  }
  assert.doesNotThrow(() => checkNumericGuardReport(report(sample), true));
  const order = find(sample, 'phone/payload/order', 'typed-invalid');
  order.kinds = 'roInvalid';
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Invalid kinds/);
  order.kinds = 'Invalid';
  find(sample, 'http/failure', 'native-byte-array-count').kinds = 'roFloat/Integer';
  assert.throws(() => checkNumericGuardReport(report(sample), true), /Invalid kinds/);
  const host = fixture();
  find(host, 'phone/payload/guideDays', 'typed-double-whole').kinds = 'roFloat';
  assert.throws(() => checkNumericGuardReport(report(host), false), /Invalid kinds/);
});

test('only HTTP parser observations change with the fix; no synthetic or caller mismatch is waived', () => {
  const sample = fixture(true);
  const row = find(sample, 'http/failure', 'parsed-decimal-whole/response');
  row.kinds = 'roInteger/Integer';
  row.actual = '';
  assert.doesNotThrow(() => checkNumericGuardReport(report(sample), true));
  assert.throws(() => checkNumericGuardReport(report(sample), true, { fixedHttp: true }), /Unexpected observation/);
  row.actual = 'at-least-1-mib';

  assert.doesNotThrow(() => checkNumericGuardReport(report(sample), true, { fixedHttp: true }));
  const postFix = postFixFixture();
  const accepted = checkNumericGuardReport(report(postFix), true, { fixedHttp: true });
  assert.equal(accepted.mismatches.length, 7);
  assert.deepEqual(assertNumericGuardNativeVerdict(accepted, 'post-fix'), { knownSynthetic: 7, reproducedHttp: 0 });
  assert.throws(() => assertNumericGuardNativeVerdict(accepted, 'pre-fix'), /Unexpected pre-fix mismatch set/);

  find(postFix, 'metadata/state', 'aa-int/schema').actual = 'fresh';
  find(postFix, 'metadata/state', 'epoch-roundtrip').actual = 'miss';
  postFix.summary.callermismatches = 1;
  const regressed = checkNumericGuardReport(report(postFix), true, { fixedHttp: true });
  assert.throws(() => assertNumericGuardNativeVerdict(regressed, 'post-fix'), /Unexpected post-fix mismatch set/);
});

test('all five post-fix HTTP rows must prove the same boxed pair recovered', () => {
  const sample = postFixFixture();
  const cases = ['aa-int/response', 'aa-int/cap', 'transport-aa-shape', 'task-cap-shape', 'native-byte-array-count'];
  for (const name of cases) {
    const row = find(sample, 'http/failure', name);
    const boxed = row.kinds;
    const wrongPair = error => error.message.startsWith(
      `Post-fix HTTP case must preserve the boxed type pair and report the size bucket: ${name}\n`,
    );
    assert.equal(row.actual, 'at-least-1-mib');
    for (const kinds of ['Integer/Integer', boxed.replace('roInteger', 'roInt')]) {
      row.kinds = kinds;
      const result = checkNumericGuardReport(report(sample), true, { fixedHttp: true });
      assert.equal(result.mismatches.length, 7);
      assert.throws(() => assertNumericGuardNativeVerdict(result, 'post-fix'), wrongPair);
    }
    row.kinds = boxed;
    row.actual = '';
    sample.summary.mismatches += 1;
    if (row.lane === 'caller-shape') sample.summary.callershapemismatches += 1;
    const result = checkNumericGuardReport(report(sample), true, { fixedHttp: true });
    assert.throws(() => assertNumericGuardNativeVerdict(result, 'post-fix'), wrongPair);
    row.actual = 'at-least-1-mib';
    sample.summary.mismatches -= 1;
    if (row.lane === 'caller-shape') sample.summary.callershapemismatches -= 1;
  }
  assert.doesNotThrow(() => assertNumericGuardNativeVerdict(
    checkNumericGuardReport(report(sample), true, { fixedHttp: true }), 'post-fix',
  ));
});
