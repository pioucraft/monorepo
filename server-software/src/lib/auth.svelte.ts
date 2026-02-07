class AuthState {
	username: string | null = $state(null);
	password: string | null = $state(null);
	hashedPassword: string | null = $state(null);
}

export const auth = new AuthState();

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
