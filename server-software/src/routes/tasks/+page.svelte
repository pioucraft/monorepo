<script lang="ts">
	import { journal, latest, loadEntries, parseContent } from '$lib/journal.svelte';
	import { onMount } from 'svelte';
	import ArrowUturnLeft from '$lib/icons/ArrowUturnLeft.svelte';

	interface Task {
		content: string;
		status: 'pending' | 'completed' | 'never';
		entryIndex: number;
		entryDate: number;
	}

	let win = window as any;

	let tasks: Task[] = $derived(
		journal.entries
			.flatMap((entry, entryIndex) => {
				const content = latest(entry).content;
				const lines = content.split('\n');
				const entryDate = latest(entry).date;
				return lines
					.filter((line) => /^-\s*\[[ x-]\]/i.test(line.trim()))
					.map((line) => {
						const trimmed = line.trim();
						const match = trimmed.match(/^-\s*\[([ x-])\]/i);
						const statusChar = match ? match[1].toLowerCase() : ' ';
						let status: Task['status'] = 'pending';
						if (statusChar === 'x') status = 'completed';
						else if (statusChar === '-') status = 'never';
						const taskContent = parseContent(trimmed.replace(/^-\s*\[[ x-]\]\s*/i, ''));
						return {
							content: taskContent,
							status,
							entryIndex,
							entryDate
						};
					});
			})
			.sort((a, b) => b.entryDate - a.entryDate)
	);

	let pendingTasks = $derived(tasks.filter((t) => t.status === 'pending'));
	let completedTasks = $derived(tasks.filter((t) => t.status === 'completed'));
	let neverTasks = $derived(tasks.filter((t) => t.status === 'never'));

	onMount(async () => {
		if (journal.entries.length === 0 && journal.loading) {
			await loadEntries();
		}
	});

	function formatDate(timestamp: number): string {
		const d = new Date(timestamp);
		return d.toLocaleDateString(undefined, {
			month: 'short',
			day: 'numeric',
			year: 'numeric'
		});
	}

	function showNote(entryIndex: number) {
		if (win.showLinkedNoteHistory) {
			const count = journal.entries.length;
			win.showLinkedNoteHistory(count - 1 - entryIndex, true);
		}
	}
</script>

<div class="min-h-screen bg-white p-8 dark:bg-black">
	<div class="mx-auto max-w-lg">
		<div class="mb-6 flex items-center justify-between">
			<h1 class="text-xl font-bold text-black dark:text-white">Tasks</h1>
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
						<p class="text-xs text-neutral-500">Pending</p>
						<p class="mt-1 text-2xl font-bold text-black dark:text-white">
							{pendingTasks.length}
						</p>
					</div>
					<div class="flex-1 border border-black p-4 dark:border-white">
						<p class="text-xs text-neutral-500">Completed</p>
						<p class="mt-1 text-2xl font-bold text-green-600 dark:text-green-400">
							{completedTasks.length}
						</p>
					</div>
					<div class="flex-1 border border-black p-4 dark:border-white">
						<p class="text-xs text-neutral-500">Never</p>
						<p class="mt-1 text-2xl font-bold text-neutral-400">{neverTasks.length}</p>
					</div>
				</div>

				{#if pendingTasks.length > 0}
					<div>
						<h2 class="mb-3 text-sm font-bold text-black dark:text-white">
							Pending ({pendingTasks.length})
						</h2>
						<div class="space-y-2">
							{#each pendingTasks as task}
								<div
									class="flex items-start gap-2 border border-black p-3 dark:border-white"
								>
									<input type="checkbox" disabled />
									<div class="flex-1">
										<p class="text-sm text-black dark:text-white">{@html task.content}</p>
										<p class="mt-1 text-xs text-neutral-500">
											<button
												type="button"
												onclick={() => showNote(task.entryIndex)}
												class="hover:underline"
											>
												{formatDate(task.entryDate)}
											</button>
										</p>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/if}

				{#if completedTasks.length > 0}
					<div>
						<h2 class="mb-3 text-sm font-bold text-green-600 dark:text-green-400">
							Completed ({completedTasks.length})
						</h2>
						<div class="space-y-2">
							{#each completedTasks as task}
								<div
									class="flex items-start gap-2 border border-green-200 bg-green-50 p-3 dark:border-green-800 dark:bg-green-900/20"
								>
									<input type="checkbox" checked disabled />
									<div class="flex-1">
										<p class="text-sm text-black dark:text-white line-through">
											{@html task.content}
										</p>
										<p class="mt-1 text-xs text-neutral-500">
											<button
												type="button"
												onclick={() => showNote(task.entryIndex)}
												class="hover:underline"
											>
												{formatDate(task.entryDate)}
											</button>
										</p>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/if}

				{#if neverTasks.length > 0}
					<div>
						<h2 class="mb-3 text-sm font-bold text-neutral-500">
							Never Finished ({neverTasks.length})
						</h2>
						<div class="space-y-2">
							{#each neverTasks as task}
								<div
									class="flex items-start gap-2 border border-neutral-300 bg-neutral-50 p-3 dark:border-neutral-700 dark:bg-neutral-900/30"
								>
									<span class="text-neutral-400">[-]</span>
									<div class="flex-1">
										<p class="text-sm text-neutral-500 line-through">
											{@html task.content}
										</p>
										<p class="mt-1 text-xs text-neutral-500">
											<button
												type="button"
												onclick={() => showNote(task.entryIndex)}
												class="hover:underline"
											>
												{formatDate(task.entryDate)}
											</button>
										</p>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/if}

				{#if tasks.length === 0}
					<p class="text-sm text-neutral-500">
						No tasks found. Use `- [ ] task` to create a task.
					</p>
				{/if}
			</div>
		{/if}
	</div>
</div>
