// Génère la clé de chiffrement du Comité, protégée par identifiant + code.
// Usage : node keygen.mjs "ethis dubois" "votre code d’accès" > keys.json
import { webcrypto as c } from 'node:crypto';
const [id, code] = process.argv.slice(2);
if (!id || !code) { console.error('Usage : node keygen.mjs "identifiant" "code"'); process.exit(1); }
const b = u => Buffer.from(u).toString('base64url');
const kp = await c.subtle.generateKey({ name: 'RSA-OAEP', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['encrypt', 'decrypt']);
const pub = await c.subtle.exportKey('spki', kp.publicKey);
const priv = await c.subtle.exportKey('pkcs8', kp.privateKey);
const n = 600000, s = c.getRandomValues(new Uint8Array(16)), iv = c.getRandomValues(new Uint8Array(12));
const base = await c.subtle.importKey('raw', new TextEncoder().encode(id.trim().toLowerCase() + ':' + code), 'PBKDF2', false, ['deriveKey']);
const k = await c.subtle.deriveKey({ name: 'PBKDF2', salt: s, iterations: n, hash: 'SHA-256' }, base, { name: 'AES-GCM', length: 256 }, false, ['encrypt']);
const d = await c.subtle.encrypt({ name: 'AES-GCM', iv }, k, priv);
console.log(JSON.stringify({ pub: b(pub), wrap: { s: b(s), iv: b(iv), d: b(d), n } }));
