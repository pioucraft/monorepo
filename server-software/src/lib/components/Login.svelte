<script lang="ts">
	import { goto } from '$app/navigation';
	import { toast } from '$lib/toast.svelte';
	import { setAuth } from '$lib/auth.svelte';

	let username = $state('');
	let password = $state('');

	async function hashPassword(input: string): Promise<string> {
		const encoded = new TextEncoder().encode(input);
		const buffer = await crypto.subtle.digest('SHA-256', encoded);
		return Array.from(new Uint8Array(buffer))
			.map((b) => b.toString(16).padStart(2, '0'))
			.join('');
	}

	async function handleSubmit(e: SubmitEvent) {
		e.preventDefault();

		const hashed = await hashPassword(password);

		const res = await fetch('/api/login', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ username, password: hashed })
		});

		if (res.ok) {
			setAuth(username, password, hashed);
			toast('Login successful', true);
			setTimeout(() => goto('/'), 1000);
		} else {
			toast('Invalid credentials', false);
		}
	}
</script>

<div class="flex min-h-screen items-center justify-center bg-white dark:bg-black">
	<form onsubmit={handleSubmit} class="w-full max-w-xs space-y-4 p-6">
		<h1 class="text-center text-xl font-bold text-black dark:text-white">Login</h1>

		<input
			type="text"
			name="username"
			placeholder="Username"
			required
			bind:value={username}
			class="w-full border border-black bg-transparent px-3 py-2 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
		/>

		<input
			type="password"
			name="password"
			placeholder="Password"
			required
			bind:value={password}
			class="w-full border border-black bg-transparent px-3 py-2 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
		/>

		<button
			type="submit"
			class="w-full cursor-pointer bg-black py-2 text-sm font-medium text-white dark:bg-white dark:text-black"
		>
			Login
		</button>
	</form>
</div>
