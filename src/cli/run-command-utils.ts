export type InterruptSignal = "SIGINT" | "SIGTERM";

export function shouldBlockResumeForRunningRun(
  runStatus: string | null | undefined,
  force: boolean,
): boolean {
  return runStatus === "running" && !force;
}

export function resolveRunCommandExitCode(opts: {
  status: "finished" | "failed" | "cancelled" | "waiting-approval";
  interruptedBySignal: InterruptSignal | null;
}): number {
  if (opts.interruptedBySignal === "SIGINT") return 130;
  if (opts.interruptedBySignal === "SIGTERM") return 143;
  return opts.status === "finished"
    ? 0
    : opts.status === "waiting-approval"
      ? 3
      : opts.status === "cancelled"
        ? 2
        : 1;
}
