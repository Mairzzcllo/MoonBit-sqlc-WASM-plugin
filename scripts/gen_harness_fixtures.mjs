#!/usr/bin/env node
/** Reference protobuf bytes for harness diff (matches plugin minimal test). */
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'scripts', 'harness-fixtures');
mkdirSync(outDir, { recursive: true });

function encodeVarint(n) {
  const out = [];
  let v = n >>> 0;
  while (v >= 0x80) {
    out.push((v & 0x7f) | 0x80);
    v >>>= 7;
  }
  out.push(v);
  return Buffer.from(out);
}

function encodeLenDelimited(fieldNum, payload) {
  const tag = (fieldNum << 3) | 2;
  return Buffer.concat([encodeVarint(tag), encodeVarint(payload.length), payload]);
}

function encodeStringField(fieldNum, s) {
  return encodeLenDelimited(fieldNum, Buffer.from(s, 'utf8'));
}

function encodeBytesField(fieldNum, b) {
  return encodeLenDelimited(fieldNum, b);
}

function encodeFile(name, contents) {
  return Buffer.concat([
    encodeStringField(1, name),
    encodeBytesField(2, contents),
  ]);
}

function encodeMinimalResponse() {
  const types = Buffer.from('package users\n\npub struct Users {\n}\n', 'utf8');
  const queries = Buffer.from('package users\n', 'utf8');
  const f1 = encodeFile('types.mbt', types);
  const f2 = encodeFile('queries.mbt', queries);
  return Buffer.concat([
    encodeLenDelimited(1, f1),
    encodeLenDelimited(1, f2),
  ]);
}

const minimal = encodeMinimalResponse();
writeFileSync(join(outDir, 'minimal_response.bin'), minimal);
console.log(`minimal_response.bin: ${minimal.length} bytes`);
console.log(minimal.subarray(0, 32).toString('hex'));
