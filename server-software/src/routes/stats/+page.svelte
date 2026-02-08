<script lang="ts">
	import { journal, latest, loadEntries } from '$lib/journal.svelte';
	import { onMount } from 'svelte';
	import ArrowUturnLeft from '$lib/icons/ArrowUturnLeft.svelte';

	let totalEntries = $derived(journal.entries.length);

	let totalWords = $derived(
		journal.entries.reduce((sum, entry) => {
			const content = latest(entry).content;
			const words = content.trim().split(/\s+/).filter((w) => w.length > 0);
			return sum + words.length;
		}, 0)
	);

	let tags = $derived(() => {
		const tagMap = new Map<string, number>();
		for (const entry of journal.entries) {
			const content = latest(entry).content;
			const matches = content.match(/#\w+/g);
			if (matches) {
				for (const tag of matches) {
					const lower = tag.toLowerCase();
					tagMap.set(lower, (tagMap.get(lower) ?? 0) + 1);
				}
			}
		}
		return [...tagMap.entries()]
			.sort((a, b) => b[1] - a[1])
			.map(([tag, count]) => ({ tag, count }));
	});

	onMount(async () => {
		if (journal.entries.length === 0 && journal.loading) {
			await loadEntries();
		}
	});
</script>

<div class="min-h-screen bg-white p-8 dark:bg-black">
	<div class="mx-auto max-w-lg">
		<div class="mb-6 flex items-center justify-between">
			<h1 class="text-xl font-bold text-black dark:text-white">Stats</h1>
			<a
				href="/"
				class="flex items-center gap-1.5 text-xs text-neutral-400 hover:text-black dark:hover:text-white"
			>
				<ArrowUturnLeft class="h-3.5 w-3.5" />
				Back
			</a>
		</div>

		{#if journal.loading}
			<p class="text-sm text-neutral-500">Loading...</p>
		{:else}
			<div class="space-y-6">
				<div class="flex gap-4">
					<div class="flex-1 border border-black p-4 dark:border-white">
						<p class="text-xs text-neutral-500">Entries</p>
						<p class="mt-1 text-2xl font-bold text-black dark:text-white">{totalEntries}</p>
					</div>
					<div class="flex-1 border border-black p-4 dark:border-white">
						<p class="text-xs text-neutral-500">Words</p>
						<p class="mt-1 text-2xl font-bold text-black dark:text-white">{totalWords}</p>
					</div>
				</div>

				<div>
					<h2 class="mb-3 text-sm font-bold text-black dark:text-white">Tags</h2>
					{#if tags().length === 0}
						<p class="text-sm text-neutral-500">No tags yet. Use #tag in your entries.</p>
					{:else}
						<div class="flex flex-wrap gap-2">
							{#each tags() as { tag, count }}
								<span class="border border-black px-2 py-1 text-xs text-black dark:border-white dark:text-white">
									{tag} <span class="text-neutral-400">({count})</span>
								</span>
							{/each}
						</div>
					{/if}
				</div>
			</div>
		{/if}
	</div>
</div>
