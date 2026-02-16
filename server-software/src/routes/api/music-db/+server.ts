import { json } from '@sveltejs/kit';
import fs from 'fs/promises';
import path from 'path';

const DB_PATH = '/home/nix/git/monorepo/data/music/music-db.json';

import { env } from '$env/dynamic/private';

function authorize(request: Request): string | null {
	const auth = request.headers.get('Authorization');
	if (!auth || auth !== env.PASSWORD) return 'Unauthorized';
	return null;
}

export const GET = async ({ request }: { request: Request }) => {
  const err = authorize(request);
  if (err) return json({ error: err }, { status: 401 });
  try {
    const data = await fs.readFile(DB_PATH, 'utf-8');
    const db = JSON.parse(data);
    return json(db);
  } catch (e: any) {
    return json({ error: 'Could not read music-db.json', details: e.message }, { status: 500 });
  }
};
