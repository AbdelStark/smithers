import { startApp } from "./solid/index.js";

function createWebRpcClient(handlers: any): any {
  const MESSAGE_NAMES = [
    "agentEvent",
    "chatMessage",
    "workflowEvent",
    "workflowFrame",
    "workspaceState",
    "toast",
  ] as const;

  const request = new Proxy({} as any, {
    get(_target, prop) {
      if (typeof prop !== "string") return undefined;
      return async (params: unknown) => {
        const res = await fetch("/rpc", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ method: prop, params: params ?? {} }),
        });
        const payload = await res.json().catch(() => ({}));
        if (!res.ok || !payload?.ok) {
          const message = payload?.error?.message ?? `RPC ${prop} failed`;
          throw new Error(message);
        }
        return payload.result as any;
      };
    },
  });

  const eventSource = new EventSource("/events");
  for (const name of MESSAGE_NAMES) {
    eventSource.addEventListener(name, (event) => {
      try {
        const data = JSON.parse((event as MessageEvent).data ?? "null");
        const handler = handlers.messages?.[name];
        if (handler) handler(data);
      } catch (err) {
        console.warn("[web rpc] failed to parse event", name, err);
      }
    });
  }

  return { request };
}

startApp(createWebRpcClient);
