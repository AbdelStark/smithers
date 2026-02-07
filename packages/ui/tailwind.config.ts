import type { Config } from "tailwindcss";

export default {
  content: ["./src/**/*.{ts,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        background: "#0B0D10",
        foreground: "#F5F7FA",
        panel: {
          DEFAULT: "#10141A",
          2: "#161C24",
          3: "#1C2430",
        },
        border: "#1E2736",
        muted: "#8B96A9",
        subtle: "#5A6577",
        accent: "#4C7DFF",
        danger: "#FF3B5C",
        success: "#3DDC97",
        warning: "#F2A43A",
      },
      fontFamily: {
        sans: ["Geist", "system-ui", "sans-serif"],
        mono: ["Geist Mono", "ui-monospace", "monospace"],
      },
    },
  },
  plugins: [],
} satisfies Config;
