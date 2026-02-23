import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";

export const securityLogs = pgTable("security_logs", {
  id: serial("id").primaryKey(),
  event: text("event").notNull(),
  ipAddress: text("ip_address").notNull(),
  createdAt: timestamp("created_at").defaultNow(),
});
