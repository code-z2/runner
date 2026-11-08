import { ed25519 } from "@noble/curves/ed25519.js";
import { base58, base64 } from "@scure/base";

const secret = ed25519.utils.randomSecretKey();
const publicKey = `ed25519:${base58.encode(ed25519.getPublicKey(secret))}`;

const wrangler = Bun.spawn(["bunx", "wrangler", "secret", "put", "ATTESTOR_SECRET_KEY"], {
  stdin: "pipe",
  stdout: "inherit",
  stderr: "inherit",
});
wrangler.stdin.write(base64.encode(secret));
await wrangler.stdin.end();
secret.fill(0);

if ((await wrangler.exited) !== 0) {
  console.error("Storing ATTESTOR_SECRET_KEY failed. Nothing was changed.");
  process.exit(1);
}

console.log(`Attestor public key: ${publicKey}`);
console.log("Pass it to the treasury contract: new(..., attestor_public_key) or set_attestor.");
