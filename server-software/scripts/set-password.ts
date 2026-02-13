import { createHash } from 'crypto';
import { writeFileSync, existsSync, readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

function promptHidden(question: string): Promise<string> {
	return new Promise((resolve) => {
		process.stdout.write(question);
		const stdin = process.stdin;
		stdin.setRawMode(true);
		stdin.resume();
		stdin.setEncoding('utf8');

		let input = '';
		const onData = (ch: string) => {
			if (ch === '\r' || ch === '\n') {
				stdin.setRawMode(false);
				stdin.pause();
				stdin.removeListener('data', onData);
				process.stdout.write('\n');
				resolve(input);
			} else if (ch === '\u0003') {
				process.stdout.write('\n');
				process.exit(0);
			} else if (ch === '\u007f' || ch === '\b') {
				if (input.length > 0) {
					input = input.slice(0, -1);
				}
			} else {
				input += ch;
			}
		};
		stdin.on('data', onData);
	});
}

function hash(input: string): string {
	return createHash('sha256').update(input).digest('hex');
}

async function main() {
	console.log(
		'\x1b[41m\x1b[37m\x1b[1m WARNING: Only run this script on a local machine. Never run it on a VPS. \x1b[0m\n'
	);

	const password = await promptHidden('Enter password: ');

	if (!password) {
		console.error('Password cannot be empty.');
		process.exit(1);
	}

	const hashed = hash(password);
	const dir = dirname(fileURLToPath(import.meta.url));
	const envPath = resolve(dir, '..', '.env');

	let content = '';
	if (existsSync(envPath)) {
		content = readFileSync(envPath, 'utf8');
		if (/^PASSWORD=.*/m.test(content)) {
			content = content.replace(/^PASSWORD=.*/m, `PASSWORD=${hashed}`);
		} else {
			content = content.trimEnd() + `\nPASSWORD=${hashed}\n`;
		}
	} else {
		content = `PASSWORD=${hashed}\n`;
	}

	writeFileSync(envPath, content);
	console.log(`Hashed password written to ${envPath}`);
}

main();
