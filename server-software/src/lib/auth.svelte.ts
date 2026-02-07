export const auth: {
	username: string | null;
	password: string | null;
	hashedPassword: string | null;
} = $state({
	username: null,
	password: null,
	hashedPassword: null
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
