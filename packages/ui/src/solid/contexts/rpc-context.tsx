import { createContext, useContext, type JSX } from "solid-js";
import type { RpcClient } from "../../rpc/types.js";

const RpcContext = createContext<RpcClient>();

export function useRpc(): RpcClient {
  const rpc = useContext(RpcContext);
  if (!rpc) throw new Error("useRpc must be used within RpcProvider");
  return rpc;
}

export function RpcProvider(props: { client: RpcClient; children: JSX.Element }) {
  return <RpcContext.Provider value={props.client}>{props.children}</RpcContext.Provider>;
}
