<script lang="ts">
	import { journal, latest, loadEntries, saveEntries, type JournalEntry, type Revision } from '$lib/journal.svelte';
	import { onMount } from 'svelte';
	import PencilSquare from '$lib/icons/PencilSquare.svelte';
	import Clock from '$lib/icons/Clock.svelte';
	import XMark from '$lib/icons/XMark.svelte';
	import MagnifyingGlass from '$lib/icons/MagnifyingGlass.svelte';
	import ChartBar from '$lib/icons/ChartBar.svelte';

	let newEntry = $state('');
	let editingIndex: number | null = $state(null);
	let editingContent = $state('');
	let historyIndex: number | null = $state(null);
	let search = $state('');

	let filteredEntries: { entry: JournalEntry; originalIndex: number }[] = $derived(
		search.trim()
			? journal.entries
				.map((entry, i) => ({ entry, originalIndex: i }))
				.filter(({ entry }) => {
					const content = latest(entry).content.toLowerCase();
					return search.trim().toLowerCase().split(/\s+/).every((word) => content.includes(word));
				})
			: journal.entries.map((entry, i) => ({ entry, originalIndex: i }))
	);

	async function addEntry() {
		if (!newEntry.trim()) return;

		const revision: Revision = { content: newEntry.trim(), date: Date.now() };
		const newEntries = [[revision], ...journal.entries];
		newEntry = '';

		await saveEntries(newEntries);
		await loadEntries();
	}

	function startEditing(index: number) {
		editingIndex = index;
		editingContent = latest(journal.entries[index]).content;
	}

	function cancelEditing() {
		editingIndex = null;
		editingContent = '';
	}

	async function saveEdit(index: number) {
		if (!editingContent.trim() || editingContent.trim() === latest(journal.entries[index]).content) {
			cancelEditing();
			return;
		}

		const revision: Revision = { content: editingContent.trim(), date: Date.now() };
		journal.entries[index] = [...journal.entries[index], revision];
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
		<div class="mb-6 flex items-center justify-between">
			<h1 class="text-xl font-bold text-black dark:text-white">Journal</h1>
			<a
				href="/stats"
				class="flex items-center gap-1.5 text-xs text-neutral-400 hover:text-black dark:hover:text-white"
			>
				<ChartBar class="h-3.5 w-3.5" />
				Stats
			</a>
		</div>

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

		<div class="relative mb-6">
			<div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3 text-neutral-400">
				<MagnifyingGlass class="h-3.5 w-3.5" />
			</div>
			<input
				bind:value={search}
				type="text"
				placeholder="Search entries..."
				class="w-full border border-black bg-transparent py-2 pl-9 pr-3 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
			/>
		</div>

		{#if journal.loading}
			<p class="text-sm text-neutral-500">Loading...</p>
		{:else if filteredEntries.length === 0}
			<p class="text-sm text-neutral-500">{search.trim() ? 'No matching entries.' : 'No entries yet.'}</p>
		{:else}
			<div>
				{#each filteredEntries as { entry, originalIndex }, i}
					{@const rev = latest(entry)}
					{@const prevRev = i > 0 ? latest(filteredEntries[i - 1].entry) : null}
					{#if i > 0 && prevRev && Math.abs(rev.date - prevRev.date) > 5 * 60 * 1000}
						<hr class="my-4 border-neutral-300 dark:border-neutral-700" />
					{/if}
					{#if i === 0 || (prevRev && !sameMinute(rev.date, prevRev.date))}
						<p class="mb-1 {i > 0 ? 'mt-4' : ''} text-xs text-neutral-500">
							{formatDate(rev.date)}
						</p>
					{/if}
					{#if editingIndex === originalIndex}
						<div class="mb-2">
							<textarea
								bind:value={editingContent}
								rows="2"
								class="w-full resize-none border border-black bg-transparent px-3 py-2 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
							></textarea>
							<div class="mt-1 flex gap-2">
								<button
									onclick={() => saveEdit(originalIndex)}
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
						<div class="mb-1 flex items-start gap-2">
							<p class="text-sm text-black dark:text-white">&gt; {rev.content}</p>
							<button
								onclick={() => startEditing(originalIndex)}
								class="shrink-0 cursor-pointer text-neutral-400 hover:text-black dark:hover:text-white"
								aria-label="Modify entry"
							>
								<PencilSquare class="h-3.5 w-3.5" />
							</button>
							{#if entry.length > 1}
								<button
									onclick={() => historyIndex = originalIndex}
									class="shrink-0 cursor-pointer text-neutral-400 hover:text-black dark:hover:text-white"
									aria-label="View history"
								>
									<Clock class="h-3.5 w-3.5" />
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
					class="cursor-pointer text-neutral-400 hover:text-black dark:hover:text-white"
					aria-label="Close"
				>
					<XMark />
				</button>
			</div>
			{#each [...journal.entries[historyIndex]].reverse() as rev, i}
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
