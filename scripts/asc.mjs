// Tiny App Store Connect API client for the release scripts (key stays in /Volumes/ZlotikaDev/keys).
//   node scripts/asc.mjs GET /v1/devices
//   node scripts/asc.mjs POST /v1/devices '{"data":{...}}'
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

const KEY_ID = process.env.ASC_KEY_ID ?? 'UH39H2RTPA';
const ISSUER = process.env.ASC_ISSUER ?? '7380b631-0b91-4890-b9c6-c6210f8a1d51';
const KEY = readFileSync(process.env.ASC_KEY ?? `/Volumes/ZlotikaDev/keys/AuthKey_${KEY_ID}.p8`, 'utf8');

const b64 = (o) => Buffer.from(typeof o === 'string' ? o : JSON.stringify(o)).toString('base64url');
export function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' });
  const body = b64({ iss: ISSUER, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' });
  const sig = createSign('SHA256').update(`${head}.${body}`).sign({ key: KEY, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${head}.${body}.${sig}`;
}

export async function asc(method, path, body) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
    body: body ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${method} ${path}: HTTP ${res.status} ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : {};
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [method = 'GET', path = '/v1/devices', body] = process.argv.slice(2);
  console.log(JSON.stringify(await asc(method, path, body), null, 1));
}
