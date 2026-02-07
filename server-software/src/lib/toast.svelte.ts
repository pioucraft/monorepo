let current: { message: string; success: boolean } | null = $state(null);
let timeout: ReturnType<typeof setTimeout> | null = null;

export function toast(message: string, success: boolean) {
	if (timeout) clearTimeout(timeout);
	current = { message, success };
	timeout = setTimeout(() => {
		current = null;
		timeout = null;
	}, 3000);
}

export function getToast() {
	return current;
}
