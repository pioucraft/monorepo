import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { desc } from "drizzle-orm";
import { integer, sqliteTable, text } from "drizzle-orm/sqlite-core";

const dbPath = process.env.SQLITE_DB_PATH ?? "../data/bot.sqlite";

const sqlite = new Database(dbPath);

sqlite.run(`
  create table if not exists messages (
    id integer primary key autoincrement,
    role text not null,
    content text not null,
    created_at integer not null
  );
`);

export const messages = sqliteTable("messages", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  role: text("role").notNull(),
  content: text("content").notNull(),
  createdAt: integer("created_at").notNull(),
});

export const db = drizzle(sqlite);

export type MessageRole = "user" | "assistant" | "system";

export async function addMessage(role: MessageRole, content: string) {
  await db.insert(messages).values({
    role,
    content,
    createdAt: Date.now(),
  });
}

export async function loadRecentMessages(limit: number) {
  const rows = await db
    .select()
    .from(messages)
    .orderBy(desc(messages.id))
    .limit(limit);

  return rows.reverse();
}
