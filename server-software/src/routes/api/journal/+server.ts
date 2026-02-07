import { json, text } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { resolve } from 'path';
import type { RequestHandler } from './$types';

function dataDir(): string {
	return resolve(process.cwd(), '..', 'data');
}

function dataPath(): string {
	return resolve(dataDir(), 'journal.enc');
}

function ensureDataFile(): string {
	const dir = dataDir();
	if (!existsSync(dir)) {
		mkdirSync(dir, { recursive: true });
	}
	const path = dataPath();
	if (!existsSync(path)) {
		writeFileSync(path, '');
	}
	return path;
}

function authorize(request: Request): string | null {
	const auth = request.headers.get('Authorization');
	if (!auth || auth !== env.PASSWORD) return 'Unauthorized';
	return null;
}

export const GET: RequestHandler = async ({ request }) => {
	const err = authorize(request);
	if (err) return json({ error: err }, { status: 401 });

	const path = ensureDataFile();
	return text(readFileSync(path, 'utf8'));
};

export const PUT: RequestHandler = async ({ request }) => {
	const err = authorize(request);
	if (err) return json({ error: err }, { status: 401 });

	const path = ensureDataFile();
	const body = await request.text();
	writeFileSync(path, body);

	return json({ success: true });
};
