import { ed25519 } from "@noble/curves/ed25519.js";
import { base58 } from "@scure/base";
import { concat, hash, utf8 } from "./codec";
import { HttpError } from "./http";

const ACTION_FUNCTION_CALL = 2;
const ACTION_TRANSFER = 3;
const ACTION_DELEGATE = 8;
const KEY_ED25519 = 0;
const NEP366_TAG = 2 ** 30 + 366;
const MAX_STRING = 4096;
const MAX_ARGS = 16384;

export interface FunctionCall {
  methodName: string;
  args: Uint8Array;
  gas: bigint;
  deposit: bigint;
}

export interface DelegateAction {
  senderId: string;
  receiverId: string;
  actions: FunctionCall[];
  nonce: bigint;
  maxBlockHeight: bigint;
  publicKey: Uint8Array;
}

export interface SignedDelegateAction {
  delegate: DelegateAction;
  delegateBytes: Uint8Array;
  signature: Uint8Array;
}

class Writer {
  private parts: Uint8Array[] = [];

  u8(value: number): this {
    this.parts.push(new Uint8Array([value]));
    return this;
  }

  u32(value: number): this {
    const bytes = new Uint8Array(4);
    new DataView(bytes.buffer).setUint32(0, value, true);
    this.parts.push(bytes);
    return this;
  }

  u64(value: bigint): this {
    const bytes = new Uint8Array(8);
    new DataView(bytes.buffer).setBigUint64(0, value, true);
    this.parts.push(bytes);
    return this;
  }

  u128(value: bigint): this {
    const bytes = new Uint8Array(16);
    const view = new DataView(bytes.buffer);
    view.setBigUint64(0, value & 0xffffffffffffffffn, true);
    view.setBigUint64(8, value >> 64n, true);
    this.parts.push(bytes);
    return this;
  }

  fixed(bytes: Uint8Array): this {
    this.parts.push(bytes);
    return this;
  }

  bytes(bytes: Uint8Array): this {
    return this.u32(bytes.length).fixed(bytes);
  }

  string(value: string): this {
    return this.bytes(utf8(value));
  }

  done(): Uint8Array {
    return concat(...this.parts);
  }
}

class Reader {
  private offset = 0;
  private readonly view: DataView;

  constructor(private readonly data: Uint8Array) {
    this.view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  }

  private need(length: number): void {
    if (this.offset + length > this.data.length) {
      throw new HttpError(400, "invalid_delegate");
    }
  }

  u8(): number {
    this.need(1);
    return this.data[this.offset++];
  }

  u32(): number {
    this.need(4);
    const value = this.view.getUint32(this.offset, true);
    this.offset += 4;
    return value;
  }

  u64(): bigint {
    this.need(8);
    const value = this.view.getBigUint64(this.offset, true);
    this.offset += 8;
    return value;
  }

  u128(): bigint {
    const low = this.u64();
    const high = this.u64();
    return (high << 64n) | low;
  }

  fixed(length: number): Uint8Array {
    this.need(length);
    const value = this.data.slice(this.offset, this.offset + length);
    this.offset += length;
    return value;
  }

  bytes(max: number): Uint8Array {
    const length = this.u32();
    if (length > max) {
      throw new HttpError(400, "invalid_delegate");
    }
    return this.fixed(length);
  }

  string(): string {
    try {
      return new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(this.bytes(MAX_STRING));
    } catch (error) {
      if (error instanceof HttpError) throw error;
      throw new HttpError(400, "invalid_delegate");
    }
  }

  get position(): number {
    return this.offset;
  }

  get finished(): boolean {
    return this.offset === this.data.length;
  }
}

function writePublicKey(writer: Writer, key: Uint8Array): Writer {
  return writer.u8(KEY_ED25519).fixed(key);
}

function readPublicKey(reader: Reader): Uint8Array {
  if (reader.u8() !== KEY_ED25519) {
    throw new HttpError(400, "unsupported_key_type");
  }
  return reader.fixed(32);
}

function writeFunctionCall(writer: Writer, call: FunctionCall): Writer {
  return writer.u8(ACTION_FUNCTION_CALL).string(call.methodName).bytes(call.args).u64(call.gas).u128(call.deposit);
}

export function encodeDelegateAction(delegate: DelegateAction): Uint8Array {
  const writer = new Writer().string(delegate.senderId).string(delegate.receiverId).u32(delegate.actions.length);
  for (const call of delegate.actions) writeFunctionCall(writer, call);
  writer.u64(delegate.nonce).u64(delegate.maxBlockHeight);
  return writePublicKey(writer, delegate.publicKey).done();
}

export function delegateDigest(delegateBytes: Uint8Array): Uint8Array {
  return hash(concat(new Writer().u32(NEP366_TAG).done(), delegateBytes));
}

export function encodeSignedDelegate(delegate: DelegateAction, signature: Uint8Array): Uint8Array {
  return new Writer().fixed(encodeDelegateAction(delegate)).u8(KEY_ED25519).fixed(signature).done();
}

export function decodeSignedDelegate(data: Uint8Array): SignedDelegateAction {
  const reader = new Reader(data);
  const senderId = reader.string();
  const receiverId = reader.string();
  const count = reader.u32();
  if (count !== 1) {
    throw new HttpError(422, "one_action_only");
  }
  const actions: FunctionCall[] = [];
  for (let i = 0; i < count; i++) {
    if (reader.u8() !== ACTION_FUNCTION_CALL) {
      throw new HttpError(422, "function_calls_only");
    }
    actions.push({ methodName: reader.string(), args: reader.bytes(MAX_ARGS), gas: reader.u64(), deposit: reader.u128() });
  }
  const nonce = reader.u64();
  const maxBlockHeight = reader.u64();
  const publicKey = readPublicKey(reader);
  const delegateBytes = data.slice(0, reader.position);
  if (reader.u8() !== KEY_ED25519) {
    throw new HttpError(400, "unsupported_key_type");
  }
  const signature = reader.fixed(64);
  if (!reader.finished) {
    throw new HttpError(400, "invalid_delegate");
  }
  return { delegate: { senderId, receiverId, actions, nonce, maxBlockHeight, publicKey }, delegateBytes, signature };
}

export function verifyDelegateSignature(signed: SignedDelegateAction): boolean {
  try {
    return ed25519.verify(signed.signature, delegateDigest(signed.delegateBytes), signed.delegate.publicKey);
  } catch {
    return false;
  }
}

export interface RelayerKey {
  secret: Uint8Array;
  publicKey: Uint8Array;
  publicKeyText: string;
}

export function parseRelayerKey(text: string): RelayerKey {
  const failure = new HttpError(500, "relayer_key_invalid");
  if (!text.startsWith("ed25519:")) throw failure;
  let raw: Uint8Array;
  try {
    raw = base58.decode(text.slice("ed25519:".length));
  } catch {
    throw failure;
  }
  if (raw.length !== 64) throw failure;
  const secret = raw.slice(0, 32);
  const publicKey = ed25519.getPublicKey(secret);
  if (publicKey.some((byte, i) => byte !== raw[32 + i])) throw failure;
  return { secret, publicKey, publicKeyText: `ed25519:${base58.encode(publicKey)}` };
}

export function buildTransferTransaction(input: {
  senderId: string;
  key: RelayerKey;
  nonce: bigint;
  blockHash: Uint8Array;
  receiverId: string;
  amount: bigint;
}): { signedTransaction: Uint8Array; hash: string } {
  const writer = new Writer().string(input.senderId);
  writePublicKey(writer, input.key.publicKey);
  writer
    .u64(input.nonce)
    .string(input.receiverId)
    .fixed(input.blockHash)
    .u32(1)
    .u8(ACTION_TRANSFER)
    .u128(input.amount);
  const transaction = writer.done();
  const transactionHash = hash(transaction);
  const signature = ed25519.sign(transactionHash, input.key.secret);
  return {
    signedTransaction: new Writer().fixed(transaction).u8(KEY_ED25519).fixed(signature).done(),
    hash: base58.encode(transactionHash),
  };
}

export function buildRelayTransaction(input: {
  relayerId: string;
  key: RelayerKey;
  nonce: bigint;
  blockHash: Uint8Array;
  signedDelegate: Uint8Array;
}): { signedTransaction: Uint8Array; hash: string } {
  const writer = new Writer().string(input.relayerId);
  writePublicKey(writer, input.key.publicKey);
  const senderId = new Reader(input.signedDelegate).string();
  writer.u64(input.nonce).string(senderId).fixed(input.blockHash).u32(1).u8(ACTION_DELEGATE).fixed(input.signedDelegate);
  const transaction = writer.done();
  const transactionHash = hash(transaction);
  const signature = ed25519.sign(transactionHash, input.key.secret);
  return {
    signedTransaction: new Writer().fixed(transaction).u8(KEY_ED25519).fixed(signature).done(),
    hash: base58.encode(transactionHash),
  };
}

export function buildFunctionTransaction(input: {
  signerId: string;
  key: RelayerKey;
  nonce: bigint;
  blockHash: Uint8Array;
  receiverId: string;
  call: FunctionCall;
}): Uint8Array {
  const writer = new Writer().string(input.signerId);
  writePublicKey(writer, input.key.publicKey);
  writer.u64(input.nonce).string(input.receiverId).fixed(input.blockHash).u32(1)
    .u8(ACTION_FUNCTION_CALL).string(input.call.methodName).bytes(input.call.args)
    .u64(input.call.gas).u128(input.call.deposit);
  const transaction = writer.done();
  const signature = ed25519.sign(hash(transaction), input.key.secret);
  return new Writer().fixed(transaction).u8(KEY_ED25519).fixed(signature).done();
}
