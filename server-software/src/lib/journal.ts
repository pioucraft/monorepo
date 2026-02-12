import { auth } from '$lib/auth.svelte';
import { encrypt, decrypt } from '$lib/crypto.client';
import { toast } from '$lib/toast.svelte';
import { writable } from 'svelte/store';

export interface Revision {
	content: string;
	date: number;
}

export interface JournalEntry {
	history: Revision[];
	hidden: boolean;
	version: number;
}

export const entries = writable<JournalEntry[]>([]);
export const loading = writable(true);

export function parseContent(content: string): string {
	return content.replace(/\n/g, '<br>');
}

export function latest(entry: JournalEntry): Revision {
	return entry.history[entry.history.length - 1];
}

export async function loadEntries() {
	loading.set(true);
	if (!auth.hashedPassword) {
		entries.set([]);
		loading.set(false);
		return;
	}

	const res = await fetch('/api/journal', {
		headers: { Authorization: auth.hashedPassword! }
	});

	if (!res.ok) {
		toast('Failed to load journal', false);
		loading.set(false);
		return;
	}

	const raw = await res.text();
	if (!raw) {
		entries.set([]);
		loading.set(false);
		return;
	}

	try {
		const decrypted = await decrypt(auth.password!, raw);
		entries.set(JSON.parse(decrypted));
	} catch {
		entries.set([]);
	}
	loading.set(false);
}

export async function saveEntries() {
	let currentEntries: JournalEntry[] = [];
	entries.subscribe(value => currentEntries = value)();
	const json = JSON.stringify(currentEntries);
	const encrypted = await encrypt(auth.password!, json);

	const res = await fetch('/api/journal', {
		method: 'PUT',
		headers: {
			Authorization: auth.hashedPassword!,
			'Content-Type': 'text/plain'
		},
		body: encrypted
	});

	if (!res.ok) {
		toast('Failed to save journal', false);
	} else {
		toast('Journal saved', true);
	}
}
