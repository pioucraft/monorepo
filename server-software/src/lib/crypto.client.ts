async function deriveKey(password: string): Promise<CryptoKey> {
	const encoded = new TextEncoder().encode(password);
	const hash = await crypto.subtle.digest('SHA-256', encoded);
	return crypto.subtle.importKey('raw', hash, 'AES-CBC', false, ['encrypt', 'decrypt']);
}

export async function encrypt(password: string, plaintext: string): Promise<string> {
	const key = await deriveKey(password);
	const iv = crypto.getRandomValues(new Uint8Array(16));
	const encoded = new TextEncoder().encode(plaintext);
	const encrypted = await crypto.subtle.encrypt({ name: 'AES-CBC', iv }, key, encoded);
	const result = new Uint8Array(iv.length + encrypted.byteLength);
	result.set(iv, 0);
	result.set(new Uint8Array(encrypted), iv.length);
	return btoa(String.fromCharCode(...result));
}

export async function decrypt(password: string, encoded: string): Promise<string> {
	const key = await deriveKey(password);
	const raw = Uint8Array.from(atob(encoded), (c) => c.charCodeAt(0));
	const iv = raw.slice(0, 16);
	const data = raw.slice(16);
	const decrypted = await crypto.subtle.decrypt({ name: 'AES-CBC', iv }, key, data);
	return new TextDecoder().decode(decrypted);
}
