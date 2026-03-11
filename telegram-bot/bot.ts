import OpenAI from "openai";
import { addMessage, loadRecentMessages } from "./db";

const telegramToken = process.env.TELEGRAM_BOT_TOKEN;
const openaiApiKey = process.env.OPENAI_API_KEY;
const allowedChatIdRaw = process.env.TELEGRAM_ALLOWED_CHAT_ID;

if (!telegramToken) {
  throw new Error("Missing TELEGRAM_BOT_TOKEN env var");
}

if (!openaiApiKey) {
  throw new Error("Missing OPENAI_API_KEY env var");
}

if (!allowedChatIdRaw) {
  throw new Error("Missing TELEGRAM_ALLOWED_CHAT_ID env var");
}

const allowedChatId = Number(allowedChatIdRaw);
if (!Number.isFinite(allowedChatId)) {
  throw new Error("Invalid TELEGRAM_ALLOWED_CHAT_ID env var");
}

const openai = new OpenAI({ apiKey: openaiApiKey });
const telegramApiBase = `https://api.telegram.org/bot${telegramToken}`;

let isBusy = false;


async function telegramRequest<T>(method: string, payload: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${telegramApiBase}/${method}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const data = await response.json();
  if (!data.ok) {
    throw new Error(`Telegram API error: ${data.description ?? "unknown error"}`);
  }

  return data.result as T;
}

async function streamResponseToTelegram(chatId: number, prompt: string) {
  const message = await telegramRequest<{ message_id: number }>("sendMessage", {
    chat_id: chatId,
    text: "Thinking...",
  });

  let accumulatedText = "";
  let lastSentText = "";
  let lastUpdateAt = 0;

  try {
    const history = await loadRecentMessages(20);
    const input = history.map((entry) => ({
      role: entry.role as "user" | "assistant" | "system",
      content: entry.content,
    }));

    input.push({
      role: "user",
      content: prompt,
    });

    const stream = openai.responses.stream({
      model: "gpt-5-mini",
      input,
      tools: [{ type: "web_search" }],
    });

    for await (const event of stream) {
      if (event.type === "response.output_text.delta") {
        accumulatedText += event.delta ?? "";
        const now = Date.now();
        if (now - lastUpdateAt > 300 && accumulatedText !== lastSentText) {
          await telegramRequest("editMessageText", {
            chat_id: chatId,
            message_id: message.message_id,
            text: accumulatedText || "...",
          });
          lastSentText = accumulatedText;
          lastUpdateAt = now;
        }
      }
    }

    if (accumulatedText && accumulatedText !== lastSentText) {
      await telegramRequest("editMessageText", {
        chat_id: chatId,
        message_id: message.message_id,
        text: accumulatedText,
        parse_mode: "Markdown",
      });
    }

    if (accumulatedText) {
      await addMessage("assistant", accumulatedText);
    }
  } catch (error) {
    const messageText = error instanceof Error ? error.message : "Unknown error";
    await telegramRequest("editMessageText", {
      chat_id: chatId,
      message_id: message.message_id,
      text: `Error: ${messageText}`,
    });
  }
}

async function pollUpdates() {
  let offset = 0;

  while (true) {
    const response = await fetch(
      `${telegramApiBase}/getUpdates?timeout=30&offset=${offset}`,
    );
    const data = await response.json();

    if (!data.ok) {
      throw new Error(`Telegram polling error: ${data.description ?? "unknown"}`);
    }

    const updates = data.result as Array<{
      update_id: number;
      message?: {
        message_id: number;
        chat: { id: number };
        text?: string;
      };
    }>;

    for (const update of updates) {
      offset = update.update_id + 1;

      const message = update.message;
      const text = message?.text?.trim();
      if (!message || !text) {
        continue;
      }

      const chatId = message.chat.id;
      if (chatId !== allowedChatId) {
        await telegramRequest("sendMessage", {
          chat_id: chatId,
          text: "This bot is restricted to a single chat.",
        });
        continue;
      }

      if (isBusy) {
        await telegramRequest("sendMessage", {
          chat_id: chatId,
          text: "Still working on your previous request.",
        });
        continue;
      }

      isBusy = true;
      try {
        if (text === "/start") {
          await telegramRequest("sendMessage", {
            chat_id: chatId,
            text: "Send me a message and I will ask GPT-5 with web search enabled.",
          });
        } else {
          await addMessage("user", text);
          await streamResponseToTelegram(chatId, text);
        }
      } finally {
        isBusy = false;
      }
    }
  }
}

pollUpdates().catch((error) => {
  console.error("Bot stopped:", error);
  process.exit(1);
});
