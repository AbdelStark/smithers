import { QueryClient, QueryClientProvider } from "@tanstack/solid-query";
import type { JSX } from "solid-js";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5000,
      refetchOnWindowFocus: false,
    },
  },
});

export { queryClient };

export function QueryProvider(props: { children: JSX.Element }) {
  return <QueryClientProvider client={queryClient}>{props.children}</QueryClientProvider>;
}
