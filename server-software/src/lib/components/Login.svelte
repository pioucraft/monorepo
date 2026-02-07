<script lang="ts">
</script>

<div class="flex min-h-screen items-center justify-center bg-white dark:bg-black">
	<form class="w-full max-w-xs space-y-4 p-6">
		<h1 class="text-center text-xl font-bold text-black dark:text-white">Login</h1>

		<input
			type="text"
			name="username"
			placeholder="Username"
			required
			class="w-full border border-black bg-transparent px-3 py-2 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
		/>

		<input
			type="password"
			name="password"
			placeholder="Password"
			required
			class="w-full border border-black bg-transparent px-3 py-2 text-sm text-black placeholder-neutral-400 focus:outline-none dark:border-white dark:text-white dark:placeholder-neutral-600"
		/>

		<button
			type="submit"
			class="w-full bg-black py-2 text-sm font-medium text-white dark:bg-white dark:text-black"
		>
			Login
		</button>
	</form>
</div>
