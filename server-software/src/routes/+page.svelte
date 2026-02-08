<script lang="ts">
	import { auth } from '$lib/auth.svelte';
	import { encrypt, decrypt } from '$lib/crypto.client';
	import { toast } from '$lib/toast.svelte';
	import { onMount } from 'svelte';

	interface Revision {
		content: string;
		date: number;
	}

	type JournalEntry = Revision[];

	let entries: JournalEntry[] = $state([]);
	let newEntry = $state('');
	let loading = $state(true);
	let editingIndex: number | null = $state(null);
	let editingContent = $state('');
	let historyIndex: number | null = $state(null);

	function latest(entry: JournalEntry): Revision {
		return entry[entry.length - 1];
	}

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

	async function saveEntries(newEntries: JournalEntry[] = entries) {
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

	async function addEntry() {
		if (!newEntry.trim()) return;

		const revision: Revision = { content: newEntry.trim(), date: Date.now() };
		const newEntries = [[revision], ...entries];
		newEntry = '';

		await saveEntries(newEntries);
		await loadEntries();
	}

	function startEditing(index: number) {
		editingIndex = index;
		editingContent = latest(entries[index]).content;
	}

	function cancelEditing() {
		editingIndex = null;
		editingContent = '';
	}

	async function saveEdit(index: number) {
		if (!editingContent.trim() || editingContent.trim() === latest(entries[index]).content) {
			cancelEditing();
			return;
		}

		const revision: Revision = { content: editingContent.trim(), date: Date.now() };
		entries[index] = [...entries[index], revision];
		editingIndex = null;
		editingContent = '';

		await saveEntries();
		await loadEntries();
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
					{@const rev = latest(entry)}
					{@const prevRev = i > 0 ? latest(entries[i - 1]) : null}
					{#if i > 0 && prevRev && Math.abs(rev.date - prevRev.date) > 5 * 60 * 1000}
						<hr class="my-4 border-neutral-300 dark:border-neutral-700" />
					{/if}
					{#if i === 0 || (prevRev && !sameMinute(rev.date, prevRev.date))}
						<p class="mb-1 {i > 0 ? 'mt-4' : ''} text-xs text-neutral-500">
							{formatDate(rev.date)}
						</p>
					{/if}
					{#if editingIndex === i}
						<div class="mb-2">
							<textarea
								bind:value={editingContent}
								rows="2"
								class="w-full resize-none border border-black bg-transparent px-3 py-2 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
							></textarea>
							<div class="mt-1 flex gap-2">
								<button
									onclick={() => saveEdit(i)}
									class="cursor-pointer bg-black px-3 py-1 text-xs font-medium text-white dark:bg-white dark:text-black"
								>
									Save
								</button>
								<button
									onclick={cancelEditing}
									class="cursor-pointer border border-black px-3 py-1 text-xs font-medium text-black dark:border-white dark:text-white"
								>
									Cancel
								</button>
							</div>
						</div>
					{:else}
						<div class="group mb-1 flex items-start gap-2">
							<p class="text-sm text-black dark:text-white">&gt; {rev.content}</p>
							<button
								onclick={() => startEditing(i)}
								class="shrink-0 cursor-pointer text-xs text-neutral-400 opacity-0 transition-opacity group-hover:opacity-100"
							>
								modify
							</button>
							{#if entry.length > 1}
								<button
									onclick={() => historyIndex = i}
									class="shrink-0 cursor-pointer text-xs text-neutral-400 opacity-0 transition-opacity group-hover:opacity-100"
								>
									history
								</button>
							{/if}
						</div>
					{/if}
				{/each}
			</div>
		{/if}
	</div>
</div>

{#if historyIndex !== null}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
		onclick={() => historyIndex = null}
		onkeydown={(e) => { if (e.key === 'Escape') historyIndex = null; }}
		role="dialog"
		tabindex="-1"
	>
		<div
			class="max-h-[80vh] w-full max-w-md overflow-y-auto border border-black bg-white p-6 dark:border-white dark:bg-black"
			onclick={(e) => e.stopPropagation()}
			role="document"
		>
			<div class="mb-4 flex items-center justify-between">
				<h2 class="text-sm font-bold text-black dark:text-white">Revision history</h2>
				<button
					onclick={() => historyIndex = null}
					class="cursor-pointer text-xs text-neutral-400 hover:text-black dark:hover:text-white"
				>
					close
				</button>
			</div>
			{#each [...entries[historyIndex]].reverse() as rev, i}
				<div class="mb-3 {i > 0 ? 'border-t border-neutral-200 pt-3 dark:border-neutral-800' : ''}">
					<p class="mb-1 text-xs text-neutral-500">
						{formatDate(rev.date)}
						{#if i === 0}
							<span class="text-neutral-400">(current)</span>
						{/if}
					</p>
					<p class="text-sm text-black dark:text-white">{rev.content}</p>
				</div>
			{/each}
		</div>
	</div>
{/if}
