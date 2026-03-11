import OpenAI from "openai";
import { addMessage, getUserFile, loadRecentMessages, updateUserFile } from "./db";

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

const tools = [
  { type: "web_search" as const },
  {
    type: "function" as const,
    name: "update_user_file",
    description: "Update the USER.md virtual file that stores user preferences and behavior notes.",
    parameters: {
      type: "object",
      properties: {
        content: { type: "string", description: "The content to write or append." },
        mode: {
          type: "string",
          enum: ["replace", "append"],
          description: "Whether to replace or append to the current USER.md content.",
        },
      },
      required: ["content"],
    },
  },
];

async function buildSystemPrompt() {
  const userFile = await getUserFile();
  return [
    "You are a helpful assistant.",
    "Use the update_user_file tool to modify USER.md whenever you learn stable user preferences, profile details, or behavioral instructions.",
    "USER.md (virtual file):",
    userFile || "(empty)",
  ].join("\n");
}

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

async function safeEditMessageText(payload: {
  chat_id: number;
  message_id: number;
  text: string;
  parse_mode?: string;
}) {
  try {
    await telegramRequest("editMessageText", payload);
  } catch (error) {
    const messageText = error instanceof Error ? error.message : "";
    if (messageText.includes("can't parse entities")) {
      await telegramRequest("editMessageText", {
        chat_id: payload.chat_id,
        message_id: payload.message_id,
        text: payload.text,
      });
      return;
    }
    throw error;
  }
}

async function runStream(options: {
  chatId: number;
  messageId: number;
  input: Array<Record<string, unknown>>;
  instructions: string;
  previousResponseId?: string;
}) {
  const { chatId, messageId, input, instructions, previousResponseId } = options;
  let accumulatedText = "";
  let lastSentText = "";
  let lastUpdateAt = 0;

  const stream = openai.responses.stream({
    model: "gpt-5-mini",
    input,
    tools,
    instructions,
    previous_response_id: previousResponseId,
  });

  for await (const event of stream) {
    if (event.type === "response.output_text.delta") {
      accumulatedText += event.delta ?? "";
      const now = Date.now();
      if (now - lastUpdateAt > 300 && accumulatedText !== lastSentText) {
        await telegramRequest("editMessageText", {
          chat_id: chatId,
          message_id: messageId,
          text: accumulatedText || "...",
        });
        lastSentText = accumulatedText;
        lastUpdateAt = now;
      }
    }
  }

  const response = await stream.finalResponse();

    if (accumulatedText && accumulatedText !== lastSentText) {
    await safeEditMessageText({
      chat_id: chatId,
      message_id: messageId,
      text: accumulatedText,
      parse_mode: "Markdown",
    });
  }

  return { text: accumulatedText, response };
}

async function streamResponseToTelegram(chatId: number, prompt: string) {
  const message = await telegramRequest<{ message_id: number }>("sendMessage", {
    chat_id: chatId,
    text: "Thinking...",
  });

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

    const instructions = await buildSystemPrompt();
    let { text: accumulatedText, response } = await runStream({
      chatId,
      messageId: message.message_id,
      input,
      instructions,
    });

    const toolCalls = response.output.filter(
      (item) => item.type === "function_call" && item.name === "update_user_file",
    );

    if (toolCalls.length > 0) {
      const toolOutputs = [] as Array<{ type: "function_call_output"; call_id: string; output: string }>;

      for (const call of toolCalls) {
        try {
          const args = JSON.parse(call.arguments ?? "{}");
          const content = typeof args.content === "string" ? args.content : "";
          const mode = args.mode === "append" ? "append" : "replace";
          await updateUserFile(content, mode);
          toolOutputs.push({ type: "function_call_output", call_id: call.call_id, output: "ok" });
        } catch (error) {
          const messageText = error instanceof Error ? error.message : "Unknown error";
          toolOutputs.push({ type: "function_call_output", call_id: call.call_id, output: `error: ${messageText}` });
        }
      }

      if (toolOutputs.length > 0) {
        const updatedInstructions = await buildSystemPrompt();
        const followUp = await runStream({
          chatId,
          messageId: message.message_id,
          input: toolOutputs,
          instructions: updatedInstructions,
          previousResponseId: response.id,
        });
        accumulatedText = followUp.text;
        response = followUp.response;
      }
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
