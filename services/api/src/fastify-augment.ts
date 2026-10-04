export {};

declare module 'fastify' {
  interface FastifyContextConfig {
    /** Route needs no bearer token (only /v1/health). */
    public?: boolean;
  }
}
