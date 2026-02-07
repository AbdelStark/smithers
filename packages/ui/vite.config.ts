import { defineConfig } from "vite";
import solidPlugin from "vite-plugin-solid";
import path from "path";

export default defineConfig({
  base: "./",
  plugins: [solidPlugin()],
  resolve: {
    alias: {
      "~": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    target: "esnext",
    outDir: "assets",
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: "main.js",
        assetFileNames: "[name][extname]",
      },
    },
  },
});
