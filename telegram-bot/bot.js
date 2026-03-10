function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

async function sendMessage(apiBase, chatId, text) {
    const sendUrl = new URL(`${apiBase}/sendMessage`);
    sendUrl.searchParams.set("chat_id", String(chatId));
    sendUrl.searchParams.set("text", text);
    await fetch(sendUrl);
}

async function main() {
    const token = process.env.TELEGRAM_BOT_TOKEN
    const allowedChatId = process.env.TELEGRAM_CHAT_ID

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
