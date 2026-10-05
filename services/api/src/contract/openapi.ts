import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

import type { FastifyInstance, FastifySchema, HTTPMethods } from 'fastify';
import { parse } from 'yaml';

type Json = null | boolean | number | string | Json[] | { [k: string]: Json };
type Ref = { $ref: string };

interface Parameter {
  name: string;
  in: 'path' | 'query' | 'header';
  required?: boolean;
  schema: Json;
}

interface Operation {
  operationId: string;
  parameters?: Array<Parameter | Ref>;
  requestBody?: { content?: Record<string, { schema: Json }> };
  responses: Record<string, { content?: Record<string, { schema: Json }> } | Ref>;
}

type PathItem = { parameters?: Array<Parameter | Ref> } & Partial<Record<(typeof METHODS)[number], Operation>>;

export interface Contract {
  paths: Record<string, PathItem>;
  components: { schemas: Record<string, Json>; parameters?: Record<string, Parameter> };
}

export interface ContractOperation {
  operationId: string;
  method: HTTPMethods;
  /** OpenAPI template, e.g. /v1/users/{userId}. */
  path: string;
  /** Fastify URL, e.g. /v1/users/:userId. */
  url: string;
}

const METHODS = ['get', 'post', 'put', 'patch', 'delete'] as const;

export const DEFAULT_CONTRACT_PATH = fileURLToPath(new URL('../../api/openapi.yaml', import.meta.url));

export function loadContract(path: string = process.env.CONTRACT_PATH ?? DEFAULT_CONTRACT_PATH): Contract {
  return parse(readFileSync(path, 'utf8')) as Contract;
}

export const toFastifyUrl = (path: string): string => path.replace(/\{(\w+)\}/g, ':$1');

/** OpenAPI → Fastify JSON schema: local refs become shared-schema ids, `example` is dropped. */
export function toFastifySchema(node: Json): Json {
  if (Array.isArray(node)) return node.map(toFastifySchema);
  if (node === null || typeof node !== 'object') return node;
  const out: { [k: string]: Json } = {};
  for (const [k, v] of Object.entries(node)) {
    if (k === 'example') continue;
    if (k === '$ref' && typeof v === 'string') {
      out.$ref = `${v.replace('#/components/schemas/', '')}#`;
      continue;
    }
    out[k] = toFastifySchema(v);
  }
  return out;
}

export function registerContractSchemas(app: FastifyInstance, contract: Contract): void {
  for (const [name, schema] of Object.entries(contract.components.schemas)) {
    app.addSchema({ $id: name, ...(toFastifySchema(schema) as Record<string, Json>) });
  }
}

function resolveParameter(contract: Contract, p: Parameter | Ref): Parameter {
  if (!('$ref' in p)) return p;
  const name = p.$ref.replace('#/components/parameters/', '');
  const found = contract.components.parameters?.[name];
  if (!found) throw new Error(`unknown parameter ${p.$ref}`);
  return found;
}

export function operations(contract: Contract): ContractOperation[] {
  const out: ContractOperation[] = [];
  for (const [path, item] of Object.entries(contract.paths)) {
    for (const m of METHODS) {
      const op = item[m];
      if (op) out.push({ operationId: op.operationId, method: m.toUpperCase() as HTTPMethods, path, url: toFastifyUrl(path) });
    }
  }
  return out;
}

/** Method, URL and validation/serialisation schemas of one operation, straight from the contract. */
export function operation(
  contract: Contract,
  operationId: string,
): { method: HTTPMethods; url: string; schema: FastifySchema } {
  for (const [path, item] of Object.entries(contract.paths)) {
    for (const m of METHODS) {
      const op = item[m];
      if (!op || op.operationId !== operationId) continue;
      const schema: FastifySchema = {};
      const params = [...(item.parameters ?? []), ...(op.parameters ?? [])]
        .map((p) => resolveParameter(contract, p))
        .filter((p) => p.in === 'path');
      if (params.length > 0) {
        schema.params = {
          type: 'object',
          additionalProperties: false,
          required: params.map((p) => p.name),
          properties: Object.fromEntries(params.map((p) => [p.name, toFastifySchema(p.schema)])),
        };
      }
      const bodySchema = op.requestBody?.content?.['application/json']?.schema;
      if (bodySchema) schema.body = toFastifySchema(bodySchema);
      const response: Record<string, Json> = {};
      for (const [status, r] of Object.entries(op.responses)) {
        if (!status.startsWith('2') || '$ref' in r) continue;
        const s = r.content?.['application/json']?.schema;
        if (s) response[status] = toFastifySchema(s);
      }
      if (Object.keys(response).length > 0) schema.response = response;
      return { method: m.toUpperCase() as HTTPMethods, url: toFastifyUrl(path), schema };
    }
  }
  throw new Error(`operation ${operationId} is not in the API contract`);
}
