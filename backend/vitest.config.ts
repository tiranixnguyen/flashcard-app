import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    setupFiles: ["./vitest.setup.ts"],
    // Các file test tích hợp dùng chung một user test trên Postgres thật và
    // xoá/tạo lại nó trước mỗi test — chạy song song sẽ giẫm lên nhau.
    fileParallelism: false,
  },
});
