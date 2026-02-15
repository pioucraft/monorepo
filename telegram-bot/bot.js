const ENV_PATH = new URL("../nix-server/.env", import.meta.url).pathname;

function parseEnvFile(contents) {
  const env = {};
  for (const line of contents.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }
    const [key, ...rest] = trimmed.split("=");
    if (!key) {
      continue;
    }
    env[key] = rest.join("=").trim();
  }
  return env;
}

async function loadEnv() {
  const file = Bun.file(ENV_PATH);
  if (!(await file.exists())) {
    return {};
  }
  const contents = await file.text();
  return parseEnvFile(contents);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const fileEnv = await loadEnv();
  const token = process.env.TELEGRAM_BOT_TOKEN || fileEnv.TELEGRAM_BOT_TOKEN;

  if (!token) {
    throw new Error("Missing TELEGRAM_BOT_TOKEN in nix-server/.env");
  }

  const apiBase = `https://api.telegram.org/bot${token}`;
  let offset = 0;

  while (true) {
    try {
      const updatesUrl = new URL(`${apiBase}/getUpdates`);
      updatesUrl.searchParams.set("timeout", "30");
      if (offset > 0) {
        updatesUrl.searchParams.set("offset", String(offset));
      }

      const response = await fetch(updatesUrl);
      const data = await response.json();

      if (!data.ok) {
        throw new Error(`Telegram API error: ${data.description || "unknown"}`);
      }

      for (const update of data.result || []) {
        offset = update.update_id + 1;
        const message = update.message;
        const text = message?.text?.trim();

        if (text === "Hello") {
          const sendUrl = new URL(`${apiBase}/sendMessage`);
          sendUrl.searchParams.set("chat_id", String(message.chat.id));
          sendUrl.searchParams.set("text", "Hi !");
          await fetch(sendUrl);
        }
      }
    } catch (error) {
      console.error("Polling error:", error);
      await sleep(1000);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
