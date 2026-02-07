import { createHash, createCipheriv, createDecipheriv, randomBytes } from 'crypto';

export function hash(input: string): string {
	return createHash('sha256').update(input).digest('hex');
}

export function encrypt(password: string, plaintext: string): string {
	const key = createHash('sha256').update(password).digest();
	const iv = randomBytes(16);
	const cipher = createCipheriv('aes-256-cbc', key, iv);
	const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
	const result = Buffer.concat([iv, encrypted]);
	return result.toString('base64');
}

export function decrypt(password: string, encoded: string): string {
	const key = createHash('sha256').update(password).digest();
	const raw = Buffer.from(encoded, 'base64');
	const iv = raw.subarray(0, 16);
	const encrypted = raw.subarray(16);
	const decipher = createDecipheriv('aes-256-cbc', key, iv);
	return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}
