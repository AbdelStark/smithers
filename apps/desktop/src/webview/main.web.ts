import { startApp } from "@smithers/ui";
import { createWebRpcClient } from "./rpc/web.js";

startApp(createWebRpcClient);
