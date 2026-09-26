import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, beforeEach } from "vitest";
import { createApp } from "../app";
import { prisma } from "../config/db";
import { DEFAULT_USER_EMAIL } from "../modules/common/defaultUser";

/**
 * Dựng Express app thật trên cổng ngẫu nhiên + dọn user test trước mỗi test.
 * An toàn trên DB dev cá nhân: vitest.setup.ts đã đổi DEFAULT_USER_EMAIL sang
 * email test riêng TRƯỚC khi module nào nạp, nên không bao giờ đụng user thật.
 */
export function useTestServer() {
  const ctx = { baseUrl: "" };
  let server: Server;

  beforeAll(async () => {
    if (!DEFAULT_USER_EMAIL.includes("test")) {
      throw new Error(
        `Từ chối chạy: DEFAULT_USER_EMAIL=${DEFAULT_USER_EMAIL} không phải user test.`,
      );
    }
    await new Promise<void>((resolve) => {
      server = createApp().listen(0, () => resolve());
    });
    ctx.baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  afterAll(async () => {
    await new Promise<void>((resolve, reject) => server.close((e) => (e ? reject(e) : resolve())));
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    await prisma.user.deleteMany({ where: { email: DEFAULT_USER_EMAIL } });
  });

  return ctx;
}

export async function call(
  baseUrl: string,
  method: string,
  path: string,
  body?: unknown,
): Promise<{ status: number; json: any }> {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: body === undefined ? {} : { "Content-Type": "application/json" },
    body: body === undefined ? null : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, json: text ? JSON.parse(text) : null };
}
