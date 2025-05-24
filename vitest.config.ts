import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    setupFiles: ["./mocks/tests/setup.ts"],
    include: ["mocks/tests/**/*.test.ts"],
    exclude: ["elm-stuff/**", "dist/**", "node_modules/**"],
    testTimeout: 10000,
  },
});
