// @ts-check
import prettier from "eslint-config-prettier";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist/", "prisma/generated/"] },
  ...tseslint.configs.recommended,
  {
    // Test đọc JSON response tuỳ ý — gõ kiểu từng response không đáng công.
    files: ["**/*.test.ts", "src/testing/**"],
    rules: { "@typescript-eslint/no-explicit-any": "off" },
  },
  prettier,
);
