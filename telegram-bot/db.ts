import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { desc, eq } from "drizzle-orm";
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

sqlite.run(`
  create table if not exists user_file (
    id integer primary key check (id = 1),
    content text not null
  );
`);

sqlite.run(`
  insert into user_file (id, content)
  select 1, ''
  where not exists (select 1 from user_file where id = 1);
`);

export const messages = sqliteTable("messages", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  role: text("role").notNull(),
  content: text("content").notNull(),
  createdAt: integer("created_at").notNull(),
});

export const userFile = sqliteTable("user_file", {
  id: integer("id").primaryKey(),
  content: text("content").notNull(),
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

export async function getUserFile() {
  const rows = await db.select().from(userFile).limit(1);
  return rows[0]?.content ?? "";
}

export async function updateUserFile(content: string, mode: "replace" | "append") {
  const current = await getUserFile();
  const nextContent = mode === "append" && current
    ? `${current}\n${content}`
    : mode === "append"
      ? content
      : content;

  await db
    .update(userFile)
    .set({ content: nextContent })
    .where(eq(userFile.id, 1));

  return nextContent;
}
