import assert from 'node:assert/strict';

const prefix = '[numeric-guard]';
const terminal = `${prefix} COMPLETE `;
const primitives = `${prefix} PRIMITIVES `;
const keyFor = (target, name) => JSON.stringify([target, name]);

// Independent of the probe's rows and summary. Type names are case-insensitive
// on Roku, but only the named representations for each input slot are valid.
export function numericGuardInventory(native) {
  const inventory = new Map();
  const variants = (host, ...aliases) => native ? [host, ...aliases] : [host];
  const i = variants('Integer', 'roInt', 'roInteger');
  const l = variants('LongInteger', 'roLongInteger');
  const f = variants('Float', 'roFloat');
  const d = variants('Double', 'roDouble');
  const b = variants('Boolean', 'roBoolean');
  const s = variants('String', 'roString');
  const nil = ['Invalid'];
  const parsedInt = native ? [...i, ...l, ...f, ...d] : i;
  const wide = native ? [...l, ...f, ...d] : l;
  const frac = native ? [...f, ...d] : f;
  const now = ['Integer'];
  const bucket = 'at-least-1-mib';
  const add = (target, name, kinds, expected, lane = 'synthetic') => {
    const key = keyFor(target, name);
    assert(!inventory.has(key), `Duplicate inventory case: ${key}`);
    inventory.set(key, { target, name, kinds, expected, lane });
  };
  const http = (name, a, z, expected, lane) => add('http/failure', name, [a, z], expected, lane);
  const cache = (name, schema, fetched, expected, lane) =>
    add('metadata/state', name, [schema, fetched, now], expected, lane);
  const pref = (target, name, kinds, expected, lane) => add(`preferences/${target}`, name, kinds, expected, lane);
  const phone = (field, name, kind, expected, lane) => add(`phone/payload/${field}`, name, [kind], expected, lane);
  const fields = ['guideDays', 'catchupOffsetMinutes', 'channelProfileIds', 'order'];

  // Decimal/exponent spellings are the only parser observations: the existing
  // guards accept part of the numeric family. Anchor the observed result to
  // the reported type, so an otherwise valid control cannot silently fail.
  const acceptedInteger = kind => ['integer', 'roint'].includes(kind.toLowerCase());
  const strictInteger = kind => acceptedInteger(kind) || kind.toLowerCase() === 'rointeger';
  const ifKind = (slot, predicate, accepted, refused) =>
    kinds => [predicate(kinds[slot]) ? accepted : refused];

  for (const [name, expected] of [
    ['primitive-int', bucket], ['default-cap', 'at-least-16-mb'],
    ['cap-boundary', ''], ['mapping-small-cap', ''], ['direct-len', bucket],
  ]) http(name, i, i, expected);
  const typed = [
    ['aa-int', i], ['long', l], ['wide-long', l],
    ['float-whole', f], ['float-fractional', f], ['double-whole', d],
    ['double-fractional', d], ['invalid', nil], ['bool', b], ['string', s],
  ];
  for (const [name, kind] of typed) {
    const expected = name === 'aa-int' ? bucket : '';
    http(`${name}/response`, kind, i, expected);
    http(`${name}/cap`, i, kind, expected);
  }
  for (const [name, kind] of [
    ['int', parsedInt], ['long', wide], ['decimal-whole', parsedInt],
    ['exponent-whole', parsedInt], ['fractional', frac], ['null', nil], ['bool', b], ['string', s],
  ]) {
    const observed = name === 'decimal-whole' || name === 'exponent-whole';
    for (const [side, a, z] of [['response', kind, i], ['cap', i, kind]]) {
      const expected = observed ? kinds => [
        kinds.every(acceptedInteger) ? bucket : '',
      ] : name === 'int' ? bucket : '';
      http(`parsed-${name}/${side}`, a, z, expected);
    }
  }
  for (const name of ['transport-aa-shape', 'task-cap-shape']) http(name, i, i, bucket, 'caller-shape');
  if (native) {
    for (const name of ['native-len', 'native-byte-array-count', 'native-stat-size']) {
      http(name, [...i, ...l], i, bucket, 'caller-shape');
    }
  }

  cache('constructed-envelope', i, i, 'fresh');
  for (const name of ['persisted-roundtrip', 'epoch-roundtrip']) cache(name, parsedInt, parsedInt, 'fresh', 'caller');
  cache('fetched-at-now', parsedInt, parsedInt, 'fresh', 'wire');
  cache('fetched-at-now-plus-one', parsedInt, parsedInt, 'miss', 'wire');
  cache('primitive-assigned/schema', i, parsedInt, 'fresh');
  cache('primitive-assigned/fetched', parsedInt, i, 'fresh');
  pref('model', 'primitive-assigned', [i], 'kept');
  for (const [name, kind] of typed) {
    const integer = name === 'aa-int';
    cache(`${name}/schema`, kind, parsedInt, integer ? 'fresh' : 'miss');
    cache(`${name}/fetched`, parsedInt, kind, integer ? 'fresh' : 'miss');
    pref('model', name, [kind], integer ? 'kept' : 'default');
  }
  for (const [name, kind, state, normal, strict] of [
    ['int', parsedInt, 'fresh', 'kept', 'kept'],
    ['wrong-int', parsedInt, 'miss', 'future', 'refused'],
    ['wide', wide, 'miss', 'default', 'refused'],
    ['decimal-whole', parsedInt], ['exponent-whole', parsedInt],
    ['fractional', frac, 'miss', 'default', 'refused'],
    ['null', nil, 'miss', 'default', 'refused'],
    ['bool', b, 'miss', 'default', 'refused'],
    ['string', s, 'miss', 'default', 'refused'],
  ]) {
    const observedCache = kinds => [kinds.slice(0, 2).every(acceptedInteger) ? 'fresh' : 'miss'];
    cache(`parsed-${name}/schema`, kind, parsedInt, state ?? observedCache, 'wire');
    cache(`parsed-${name}/fetched`, parsedInt, kind, state ?? observedCache, 'wire');
    pref('load', name, [kind], normal ?? ifKind(0, acceptedInteger, 'kept', 'default'), 'comparison');
    if (native) {
      const lane = name === 'int' ? 'caller' : 'wire';
      pref('strict', name, [kind, i], strict ?? ifKind(0, strictInteger, 'kept', 'refused'), lane);
      const cold = kinds => [strictInteger(kinds[0]) ? (acceptedInteger(kinds[0]) ? 'kept' : 'default') : 'refused'];
      pref('cold-load', name, [kind], strict ?? cold, lane);
    }
  }
  pref('roundtrip', 'writer', [i, parsedInt], 'kept', native ? 'caller' : 'comparison');

  for (const field of fields) {
    for (const name of ['primitive-assigned', 'literal-field']) phone(field, name, i, 'accepted');
    for (const [name, kind] of typed) {
      if (!native && kind === d) {
        phone(field, `typed-${name}`, kind, () => ['host-fix-unsupported'], 'host-only');
      } else {
        const refused = ['float-fractional', 'double-fractional', 'bool', 'string'].includes(name)
          || (name === 'wide-long' && field === 'guideDays');
        const absent = name === 'invalid';
        phone(field, `typed-${name}`, kind, absent ? (field === 'channelProfileIds' ? 'refused' : 'default')
          : refused ? 'refused' : 'accepted');
      }
    }
  }
  for (const [name, kind, version, payload] of [
    ['int', parsedInt, 'accepted', 'accepted'], ['wrong-int', parsedInt, 'refused', 'accepted'],
    ['guide-range', parsedInt, 'refused', 'accepted'], ['wide', wide, 'refused', 'accepted'],
    ['decimal-whole', parsedInt, 'accepted', 'accepted'], ['exponent-whole', parsedInt, 'accepted', 'accepted'],
    ['fractional', frac, 'refused', 'refused'], ['null', nil, 'refused', 'default'],
    ['bool', b, 'refused', 'refused'], ['string', s, 'refused', 'refused'],
  ]) {
    const lane = name === 'int' ? 'caller' : 'wire';
    add('phone/envelope', name, [kind], version, lane);
    for (const field of fields) {
      const refused = (field === 'channelProfileIds' && name === 'null')
        || (field === 'guideDays' && ['guide-range', 'wide'].includes(name));
      phone(field, name, kind, refused ? 'refused' : payload, lane);
    }
  }
  phone('guideDays', 'guide-below-min', parsedInt, 'refused', 'wire');
  phone('guideDays', 'guide-min', parsedInt, 'accepted', 'wire');
  phone('guideDays', 'guide-max', parsedInt, 'accepted', 'wire');
  return inventory;
}

function parseRecord(json, keys, context) {
  const record = JSON.parse(json);
  assert(record && typeof record === 'object' && !Array.isArray(record), `Invalid ${context} record`);
  assert.deepEqual(Object.keys(record).sort(), [...keys].sort(), `Invalid ${context} fields`);
  // Reports are flat records. JSON.parse would silently overwrite repeated
  // fields (including escaped spellings of an existing key).
  const wireKeys = [...json.matchAll(/("(?:[^"\\]|\\.)*")\s*(:)?/g)]
    .filter(match => match[2]).map(match => JSON.parse(match[1]));
  assert.deepEqual(wireKeys.sort(), [...keys].sort(), `Duplicate or nested ${context} fields`);
  return record;
}

const outcomeFor = target => {
  if (target === 'http/failure') return ['', 'at-least-1-mib', 'at-least-16-mb'];
  if (target === 'metadata/state') return ['fresh', 'stale', 'miss'];
  if (target.startsWith('preferences/')) return ['kept', 'default', 'future', 'refused'];
  if (target === 'phone/envelope') return ['accepted', 'refused'];
  return ['accepted', 'refused', 'default', 'changed-value', 'bad-default'];
};
const consoleError = /(?:\bERROR\s*:|\berror &h|\bSyntax Error\b|\bCompile Error\b|\bError in XML\b|\bERROR compiling\b|\bCompilation Failed\b)/i;

export function checkNumericGuardReport(log, native) {
  const inventory = numericGuardInventory(native);
  const seen = new Set();
  const mismatches = [];
  let observations = 0;
  let sawPrimitives = false;
  let summary;
  for (const raw of log.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line.startsWith(prefix)) {
      assert(!consoleError.test(line), `Probe console error: ${line}`);
      continue;
    }
    assert(!summary, 'Unexpected probe record after terminal marker');
    if (line.startsWith(terminal)) {
      summary = parseRecord(line.slice(terminal.length), [
        'native', 'rows', 'mismatches', 'callermismatches', 'callershapemismatches', 'observations',
      ], 'summary');
      continue;
    }
    if (line.startsWith(primitives)) {
      assert(!sawPrimitives, 'Duplicate primitive control');
      const control = parseRecord(line.slice(primitives.length), ['one', 'fetched'], 'primitive control');
      for (const kind of Object.values(control)) {
        assert(typeof kind === 'string' && kind.toLowerCase() === 'integer', 'Invalid primitive control type');
      }
      sawPrimitives = true;
      continue;
    }

    const row = parseRecord(line.slice(prefix.length), ['target', 'name', 'kinds', 'actual', 'expected', 'lane'], 'case');
    for (const value of Object.values(row)) assert.equal(typeof value, 'string', 'Non-string case field');
    const key = keyFor(row.target, row.name);
    const spec = inventory.get(key);
    assert(spec, `Unexpected case: ${key}`);
    assert(!seen.has(key), `Duplicate case: ${key}`);
    seen.add(key);
    assert(!['fixture-error', 'runtime-exception', 'bad-category', 'bad-result'].includes(row.actual),
      `Fixture or runtime error: ${key}: ${row.actual}`);
    assert.equal(row.lane, spec.lane, `Wrong lane: ${key}`);
    const observed = typeof spec.expected === 'function';
    assert.equal(row.expected, observed ? 'observe' : spec.expected, `Wrong expectation: ${key}`);
    const kinds = row.kinds.split('/');
    assert(kinds.length === spec.kinds.length && kinds.every((kind, slot) =>
      spec.kinds[slot].some(allowed => allowed.toLowerCase() === kind.toLowerCase())), `Invalid kinds for ${key}: ${row.kinds}`);
    if (observed) {
      assert(spec.expected(kinds).includes(row.actual), `Unexpected observation for ${key}: ${row.kinds} -> ${row.actual}`);
      observations += 1;
    } else {
      assert(outcomeFor(row.target).includes(row.actual), `Invalid outcome for ${key}: ${row.actual}`);
      if (row.actual !== spec.expected) mismatches.push(row);
    }
  }
  assert(summary, 'Missing terminal marker');
  assert(sawPrimitives, 'Missing primitive control');
  const missing = [...inventory.keys()].filter(key => !seen.has(key));
  assert(!missing.length, `Missing cases: ${missing.join(', ')}`);
  const caller = mismatches.filter(row => row.lane === 'caller').length;
  const callerShape = mismatches.filter(row => row.lane === 'caller-shape').length;
  assert.deepEqual(summary, {
    native, rows: inventory.size, mismatches: mismatches.length,
    callermismatches: caller, callershapemismatches: callerShape, observations,
  }, 'Wrong terminal summary');
  return { summary, mismatches };
}
