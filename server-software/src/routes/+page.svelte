<script lang="ts">
	import { auth } from '$lib/auth.svelte';
	import { encrypt, decrypt } from '$lib/crypto.client';
	import { toast } from '$lib/toast.svelte';
	import { onMount } from 'svelte';

	interface JournalEntry {
		content: string;
		date: number;
	}

	let entries: JournalEntry[] = $state([]);
	let newEntry = $state('');
	let loading = $state(true);

	async function loadEntries() {
		if (!auth.hashedPassword) {
			loading = false;
			return;
		}

		const res = await fetch('/api/journal', {
			headers: { Authorization: auth.hashedPassword! }
		});

		if (!res.ok) {
			toast('Failed to load journal', false);
			loading = false;
			return;
		}

		const raw = await res.text();
		if (!raw) {
			entries = [];
			loading = false;
			return;
		}

		try {
			const decrypted = await decrypt(auth.password!, raw);
			entries = JSON.parse(decrypted);
		} catch {
			entries = [];
		}
		loading = false;
	}

	async function saveEntries() {
		const json = JSON.stringify(entries);
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
		}
	}

	async function addEntry() {
		if (!newEntry.trim()) return;

		entries = [{ content: newEntry.trim(), date: Date.now() }, ...entries];
		newEntry = '';

		await saveEntries();
		toast('Entry added', true);
	}

	function formatDate(timestamp: number): string {
		const d = new Date(timestamp);
		const day = d.toLocaleDateString(undefined, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
		const time = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
		return `${day} ${time}`;
	}

	function sameMinute(a: number, b: number): boolean {
		const da = new Date(a);
		const db = new Date(b);
		return (
			da.getFullYear() === db.getFullYear() &&
			da.getMonth() === db.getMonth() &&
			da.getDate() === db.getDate() &&
			da.getHours() === db.getHours() &&
			da.getMinutes() === db.getMinutes()
		);
	}

	onMount(loadEntries);
</script>

<div class="min-h-screen bg-white p-8 dark:bg-black">
	<div class="mx-auto max-w-lg">
		<h1 class="mb-6 text-xl font-bold text-black dark:text-white">Journal</h1>

		<form onsubmit={(e) => { e.preventDefault(); addEntry(); }} class="mb-8 space-y-2">
			<textarea
				bind:value={newEntry}
				placeholder="Write something..."
				rows="3"
				class="w-full resize-none border border-black bg-transparent px-3 py-2 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
			></textarea>
			<button
				type="submit"
				class="w-full cursor-pointer bg-black py-2 text-sm font-medium text-white dark:bg-white dark:text-black"
			>
				Add entry
			</button>
		</form>

		{#if loading}
			<p class="text-sm text-neutral-500">Loading...</p>
		{:else if entries.length === 0}
			<p class="text-sm text-neutral-500">No entries yet.</p>
		{:else}
			<div>
				{#each entries as entry, i}
					{#if i > 0 && Math.abs(entry.date - entries[i - 1].date) > 5 * 60 * 1000}
						<hr class="my-4 border-neutral-300 dark:border-neutral-700" />
					{/if}
					{#if i === 0 || !sameMinute(entry.date, entries[i - 1].date)}
						<p class="mb-1 {i > 0 ? 'mt-4' : ''} text-xs text-neutral-500">{formatDate(entry.date)}</p>
					{/if}
					<p class="mb-1 text-sm text-black dark:text-white">&gt; {entry.content}</p>
				{/each}
			</div>
		{/if}
	</div>
</div>
