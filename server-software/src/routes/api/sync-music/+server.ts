import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { readdirSync, writeFileSync } from 'fs';
import { resolve } from 'path';
import { extname } from 'path';
import type { RequestHandler } from './$types';

// Dynamic import to avoid require issues in ESM
const mm = await import('music-metadata');

function musicDir(): string {
	// Use absolute directory
	return '/home/nix/git/monorepo/data/music';
}

function dbPath(): string {
	return resolve(musicDir(), 'music-db.json');
}

function authorize(request: Request): string | null {
	const auth = request.headers.get('Authorization');
	if (!auth || auth !== env.PASSWORD) return 'Unauthorized';
	return null;
}

export const GET: RequestHandler = async ({ request }) => {
	const err = authorize(request);
	if (err) return json({ error: err }, { status: 401 });

	const dir = musicDir();
	let files: string[];
	try {
		files = readdirSync(dir);
	} catch (e) {
		return json({ error: 'Could not read music directory.' }, { status: 500 });
	}

	const mp3s = files.filter(f => extname(f).toLowerCase() === '.mp3');
	const result: Record<string, string> = {};

	for (const filename of mp3s) {
		try {
			const filePath = resolve(dir, filename);
			const metadata = await mm.parseFile(filePath, { duration: false });
			const album = metadata.common.album || '';
			result[filename] = album;
		} catch (e) {
			result[filename] = '';
		}
	}

	try {
		writeFileSync(dbPath(), JSON.stringify(result, null, 2));
	} catch (e) {
		return json({ error: 'Failed to write music-db.json.' }, { status: 500 });
	}

	return json({ success: true, count: mp3s.length });
};
