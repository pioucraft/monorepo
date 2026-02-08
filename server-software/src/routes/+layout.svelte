<script lang="ts">
	import './layout.css';
	import favicon from '$lib/assets/favicon.svg';
	import Toast from '$lib/components/Toast.svelte';
	import { auth, clearAuth } from '$lib/auth.svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { onMount } from 'svelte';

	let { children } = $props();

	$effect(() => {
		if (!auth.username && !page.url.pathname.startsWith('/login')) {
			goto('/login');
		}
	});

	onMount(() => {
		function handleVisibilityChange() {
			if (document.visibilityState === 'hidden' && auth.username) {
				clearAuth();
			}
		}
		document.addEventListener('visibilitychange', handleVisibilityChange);
		return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
	});
</script>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>
<Toast />
{@render children()}
