import { spawn } from "node:child_process";

export async function getJjPointer(): Promise<string | null> {
  return await new Promise((resolve) => {
    const child = spawn("jj", ["log", "-r", "@", "--no-graph", "--template", "change_id"], {
      stdio: ["ignore", "pipe", "ignore"],
    });
    let out = "";
    child.stdout.on("data", (chunk) => (out += chunk.toString("utf8")));
    child.on("error", () => resolve(null));
    child.on("close", (code) => {
      if (code === 0) resolve(out.trim() || null);
      else resolve(null);
    });
  });
}
