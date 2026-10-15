export {};

declare module 'fastify' {
  interface FastifyContextConfig {
    /** Route needs no bearer token (only /v1/health). */
    public?: boolean;
  }
  interface FastifyInstance {
    /** Every registered method + URL (HEAD excluded), for the contract test. */
    routeTable: Array<{ method: string; url: string }>;
  }
}
