<script lang="ts">
	import { getToast } from '$lib/toast.svelte';
</script>

{#if getToast()}
	{@const t = getToast()!}
	<div
		class="fixed top-4 left-1/2 z-50 -translate-x-1/2 border px-4 py-2 text-sm {t.success
			? 'border-black bg-white text-black dark:border-white dark:bg-black dark:text-white'
			: 'border-red-600 bg-red-600 text-white'}"
	>
		{t.message}
	</div>
{/if}
