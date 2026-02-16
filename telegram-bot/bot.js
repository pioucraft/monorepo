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
  const fs = await import('fs/promises');
  try {
    const contents = await fs.readFile(ENV_PATH, 'utf8');
    return parseEnvFile(contents);
  } catch (err) {
    return {};
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function sendMessage(apiBase, chatId, text) {
  const sendUrl = new URL(`${apiBase}/sendMessage`);
  sendUrl.searchParams.set("chat_id", String(chatId));
  sendUrl.searchParams.set("text", text);
  await fetch(sendUrl);
}

async function runDownloadWithLiveOutput(url, onLine) {
  const { spawn } = await import('child_process');
  const proc = spawn("sh", [
    "/home/nix/git/monorepo/nix-server/download-music.sh",
    url,
  ]);

  const decoder = new TextDecoder();

  async function streamLines(stream, sendLine) {
    let buffer = "";
    for await (const chunk of stream) {
      buffer += decoder.decode(chunk);
      let idx;
      while ((idx = buffer.indexOf("\n")) !== -1) {
        const line = buffer.slice(0, idx).trim();
        buffer = buffer.slice(idx + 1);
        if (line) await sendLine(line);
      }
    }
    if (buffer.trim()) await sendLine(buffer.trim());
  }

   // Start streaming both stdout and stderr
   await Promise.all([
     streamLines(proc.stderr, line => onLine(`[stderr] ${line}`)),
   ]);

  return new Promise((resolve) => {
    proc.on('close', (code) => resolve(code === 0));
  });
}

async function main() {
  const fileEnv = await loadEnv();
   const token = process.env.TELEGRAM_BOT_TOKEN || fileEnv.TELEGRAM_BOT_TOKEN;
   const allowedChatId = process.env.TELEGRAM_CHAT_ID || fileEnv.TELEGRAM_CHAT_ID;

   if (!token) {
     throw new Error("Missing TELEGRAM_BOT_TOKEN in nix-server/.env");
   }
   if (!allowedChatId) {
     throw new Error("Missing TELEGRAM_CHAT_ID in nix-server/.env");
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

         if (!message || !text) {
           continue;
         }

         // Restrict to allowed chat ID
         if (String(message.chat.id) !== String(allowedChatId)) {
           // Optionally: await sendMessage(apiBase, message.chat.id, "Sorry, not authorized.");
           continue;
         }

         if (text === "Hello") {
           await sendMessage(apiBase, message.chat.id, "Hi, how are you ?");
           continue;
         }

         const downloadMatch = text.match(/^\/(ytdownload|musicdownload)(?:@\w+)?\s+(.+)$/i);
        if (downloadMatch) {
          const url = downloadMatch[2].trim();
          if (!url) {
            await sendMessage(
              apiBase,
              message.chat.id,
              "Usage: /ytdownload <url>"
            );
            continue;
          }

           await sendMessage(apiBase, message.chat.id, "Starting download...");

           // Stream CLI output to Telegram chat incrementally
           let outputBuffer = [];
           let flushTimer = null;
           const flushBuffer = async () => {
             if (outputBuffer.length > 0) {
               await sendMessage(apiBase, message.chat.id, outputBuffer.join('\n').slice(0, 4000));
               outputBuffer = [];
             }
             flushTimer = null;
           };
           const success = await runDownloadWithLiveOutput(url, async (line) => {
             outputBuffer.push(line);
             if (!flushTimer) {
               flushTimer = setTimeout(flushBuffer, 1250);
             }
             if (outputBuffer.length > 6) {
               await flushBuffer();
             }
           });
           await flushBuffer();
           await sendMessage(
             apiBase,
             message.chat.id,
             success ? "Download complete." : "Download failed."
           );
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
