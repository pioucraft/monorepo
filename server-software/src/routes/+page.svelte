<script lang="ts">
	import { journal, latest, loadEntries, saveEntries, parseContent, type JournalEntry, type Revision } from '$lib/journal.svelte';
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
	let showHidden = $state(false);
	let actionModalIndex: number | null = $state(null);

	let filteredEntries: { entry: JournalEntry; originalIndex: number }[] = $derived(
		journal.entries
			.map((entry, i) => ({ entry, originalIndex: i }))
			.filter(({ entry }) => {
				if (entry.hidden && !showHidden) return false;
				if (!search.trim()) return true;
				const content = latest(entry).content.toLowerCase();
				return search.trim().toLowerCase().split(/\s+/).every((word) => content.includes(word));
			})
	);

	async function addEntry() {
		if (!newEntry.trim()) return;

		const revision: Revision = { content: newEntry.trim(), date: Date.now() };
		const newEntryObj: JournalEntry = { history: [revision], hidden: false, version: 1 };
		const newEntries = [newEntryObj, ...journal.entries];
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
		journal.entries[index].history = [...journal.entries[index].history, revision];
		editingIndex = null;
		editingContent = '';

		await saveEntries();
		await loadEntries();
	}

	async function toggleCheckbox(entryIndex: number, checkboxIndex: number) {
		const currentContent = latest(journal.entries[entryIndex]).content;
		const regex = /\[(\s*x?)\]/gi;
		let match;
		let matches = [];
		while ((match = regex.exec(currentContent)) !== null) {
			matches.push({ index: match.index, match: match[0], checked: match[1].toLowerCase().includes('x') });
		}
		if (checkboxIndex >= matches.length) return;
		const target = matches[checkboxIndex];
		const newChecked = !target.checked;
		const newSymbol = newChecked ? '[x]' : '[ ]';
		const newContent = currentContent.slice(0, target.index) + newSymbol + currentContent.slice(target.index + target.match.length);

		const revision: Revision = { content: newContent, date: Date.now() };
		const newJournal = journal.entries.map((entry, i) =>
			i === entryIndex ? { ...entry, history: [...entry.history, revision] } : entry
		);

		await saveEntries(newJournal);
		await loadEntries();
	}

	// Expose toggleCheckbox globally
	if (typeof window !== 'undefined') {
		(window as any).toggleCheckbox = toggleCheckbox;
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
			<div class="flex items-center gap-4">
				<button
					onclick={() => showHidden = !showHidden}
					class="cursor-pointer border border-black px-3 py-1 text-xs font-medium text-black dark:border-white dark:text-white"
				>
					{showHidden ? 'Hide hidden' : 'Show hidden'}
				</button>
				<a
					href="/stats"
					class="flex items-center gap-1.5 text-xs text-neutral-400 hover:text-black dark:hover:text-white"
				>
					<ChartBar class="h-3.5 w-3.5" />
					Stats
				</a>
			</div>
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
							<p class="text-sm text-black dark:text-white break-words">&gt; {@html parseContent(rev.content, originalIndex)}</p>
							<button
								onclick={() => actionModalIndex = originalIndex}
								class="shrink-0 cursor-pointer text-neutral-400 hover:text-black dark:hover:text-white rotate-90 float-start"
								aria-label="More actions"
							>
								...
							</button>
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
			{#each [...journal.entries[historyIndex].history].reverse() as rev, i}
				<div class="mb-3 {i > 0 ? 'border-t border-neutral-200 pt-3 dark:border-neutral-800' : ''}">
					<p class="mb-1 text-xs text-neutral-500">
						{formatDate(rev.date)}
						{#if i === 0}
							<span class="text-neutral-400">(current)</span>
						{/if}
					</p>
					<p class="text-sm text-black dark:text-white break-words">{@html parseContent(rev.content)}</p>
				</div>
			{/each}
		</div>
	</div>
{/if}

{#if actionModalIndex !== null}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
		onclick={() => actionModalIndex = null}
		onkeydown={(e) => { if (e.key === 'Escape') actionModalIndex = null; }}
		role="dialog"
		tabindex="-1"
	>
		<div
			class="w-full max-w-xs border border-black bg-white p-4 dark:border-white dark:bg-black"
			onclick={(e) => e.stopPropagation()}
			role="document"
		>
			<div class="mb-4 flex items-center justify-between">
				<h2 class="text-sm font-bold text-black dark:text-white">Actions</h2>
				<button
					onclick={() => actionModalIndex = null}
					class="cursor-pointer text-neutral-400 hover:text-black dark:hover:text-white"
					aria-label="Close"
				>
					<XMark />
				</button>
			</div>
			<div class="space-y-2">
				<button
					onclick={() => { startEditing(actionModalIndex!); actionModalIndex = null; }}
					class="flex w-full items-center gap-2 cursor-pointer border border-black py-2 px-3 text-sm text-black hover:bg-black hover:text-white dark:border-white dark:text-white dark:hover:bg-white dark:hover:text-black"
				>
					<PencilSquare class="h-4 w-4" />
					Edit
				</button>
				{#if journal.entries[actionModalIndex!].history.length > 1}
					<button
						onclick={() => { historyIndex = actionModalIndex; actionModalIndex = null; }}
						class="flex w-full items-center gap-2 cursor-pointer border border-black py-2 px-3 text-sm text-black hover:bg-black hover:text-white dark:border-white dark:text-white dark:hover:bg-white dark:hover:text-black"
					>
						<Clock class="h-4 w-4" />
						View History
					</button>
				{/if}
				<button
					onclick={async () => {
						const newJournal = journal.entries.map((entry, i) =>
							i === actionModalIndex ? { ...entry, hidden: !entry.hidden } : entry
						);
						await saveEntries(newJournal);
						await loadEntries();
						actionModalIndex = null;
					}}
					class="flex w-full items-center gap-2 cursor-pointer border border-black py-2 px-3 text-sm text-black hover:bg-black hover:text-white dark:border-white dark:text-white dark:hover:bg-white dark:hover:text-black"
				>
					<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
						{#if journal.entries[actionModalIndex!].hidden}
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21" />
						{:else}
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
						{/if}
					</svg>
					{journal.entries[actionModalIndex!].hidden ? 'Unhide' : 'Hide'}
				</button>
			</div>
		</div>
	</div>
{/if}
