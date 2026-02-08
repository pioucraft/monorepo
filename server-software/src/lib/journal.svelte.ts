import { auth } from '$lib/auth.svelte';
import { encrypt, decrypt } from '$lib/crypto.client';
import { toast } from '$lib/toast.svelte';

export interface Revision {
	content: string;
	date: number;
}

export type JournalEntry = Revision[];

class JournalState {
	entries: JournalEntry[] = $state([]);
	loading: boolean = $state(true);
}

export const journal = new JournalState();

export function latest(entry: JournalEntry): Revision {
	return entry[entry.length - 1];
}

export async function loadEntries() {
	if (!auth.hashedPassword) {
		journal.loading = false;
		return;
	}

	const res = await fetch('/api/journal', {
		headers: { Authorization: auth.hashedPassword! }
	});

	if (!res.ok) {
		toast('Failed to load journal', false);
		journal.loading = false;
		return;
	}

	const raw = await res.text();
	if (!raw) {
		journal.entries = [];
		journal.loading = false;
		return;
	}

	try {
		const decrypted = await decrypt(auth.password!, raw);
		journal.entries = JSON.parse(decrypted);
	} catch {
		journal.entries = [];
	}
	journal.loading = false;
}

export async function saveEntries(newEntries: JournalEntry[] = journal.entries) {
	const json = JSON.stringify(newEntries);
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
