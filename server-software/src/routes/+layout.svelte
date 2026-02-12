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
		let logoutTimeout: number | null = null;
		function handleVisibilityChange() {
			if (document.visibilityState === 'hidden' && auth.username) {
				logoutTimeout = setTimeout(() => {
					clearAuth();
				}, 30000); // 30 seconds delay
			} else if (document.visibilityState === 'visible') {
				if (logoutTimeout) {
					clearTimeout(logoutTimeout);
					logoutTimeout = null;
				}
			}
		}
		document.addEventListener('visibilitychange', handleVisibilityChange);
		return () => {
			document.removeEventListener('visibilitychange', handleVisibilityChange);
			if (logoutTimeout) {
				clearTimeout(logoutTimeout);
			}
		};
	});
</script>

<svelte:head><link rel="icon" href={favicon} /></svelte:head>
<Toast />
{@render children()}
