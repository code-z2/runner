import { ed25519 } from "@noble/curves/ed25519.js";
import { base58 } from "@scure/base";

const secret = ed25519.utils.randomSecretKey();
const publicKey = ed25519.getPublicKey(secret);
const publicKeyText = `ed25519:${base58.encode(publicKey)}`;
const secretText = `ed25519:${base58.encode(new Uint8Array([...secret, ...publicKey]))}`;

const wrangler = Bun.spawn(["bunx", "wrangler", "secret", "put", "RELAYER_SECRET_KEY"], {
  stdin: "pipe",
  stdout: "inherit",
  stderr: "inherit",
});
wrangler.stdin.write(secretText);
await wrangler.stdin.end();
secret.fill(0);

if ((await wrangler.exited) !== 0) {
  console.error("Storing RELAYER_SECRET_KEY failed. Nothing was changed.");
  process.exit(1);
}

console.log(`Relayer public key: ${publicKeyText}`);
console.log("Add it as a full access key on RELAYER_ACCOUNT_ID, or create that account with it.");
