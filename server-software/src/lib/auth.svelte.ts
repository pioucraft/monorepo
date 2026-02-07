export const auth = $state({
	username: null as string | null,
	password: null as string | null,
	hashedPassword: null as string | null
});

export function setAuth(username: string, password: string, hashedPassword: string) {
	auth.username = username;
	auth.password = password;
	auth.hashedPassword = hashedPassword;
}

export function clearAuth() {
	auth.username = null;
	auth.password = null;
	auth.hashedPassword = null;
}
