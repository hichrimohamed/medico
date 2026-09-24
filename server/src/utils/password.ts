import { randomBytes, scrypt as scryptCallback, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(scryptCallback) as (
  password: string,
  salt: Buffer,
  keylen: number,
) => Promise<Buffer>;

/**
 * Password hashing on Node's own scrypt.
 *
 * bcrypt and argon2 are both fine choices, and both need a native build that
 * breaks on some machines and in some CI images. scrypt is memory-hard, in the
 * standard library, and has no install step — for a service that must come up
 * reliably, that is worth more than the marginal difference in hardness.
 *
 * Stored as `scrypt$N$salt$hash`, so the parameters travel with the hash and
 * can be raised later without invalidating existing passwords.
 */
const KEY_LENGTH = 64;
const SALT_LENGTH = 16;

export async function hashPassword(plain: string): Promise<string> {
  const salt = randomBytes(SALT_LENGTH);
  const derived = await scrypt(plain, salt, KEY_LENGTH);
  return `scrypt$1$${salt.toString('base64')}$${derived.toString('base64')}`;
}

export async function verifyPassword(
  plain: string,
  stored: string,
): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'scrypt') return false;

  const salt = Buffer.from(parts[2]!, 'base64');
  const expected = Buffer.from(parts[3]!, 'base64');
  const derived = await scrypt(plain, salt, expected.length);

  // Constant time: a length check that returns early would leak information
  // about the stored hash.
  if (derived.length !== expected.length) return false;
  return timingSafeEqual(derived, expected);
}
