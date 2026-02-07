import { json } from '@sveltejs/kit';
import { env } from '$env/dynamic/private';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	const { username, password } = await request.json();

	if (username !== 'admin' || password !== env.PASSWORD) {
		return json({ success: false, message: 'Invalid credentials' }, { status: 401 });
	}

	return json({ success: true });
};
