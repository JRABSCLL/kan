import { randomUUID } from "crypto";
import type { CreateNextContextOptions } from "@trpc/server/adapters/next";
import type { NextApiRequest } from "next";
import type { OpenApiMeta } from "trpc-to-openapi";
import { initTRPC, TRPCError } from "@trpc/server";
import { env } from "next-runtime-env";
import superjson from "superjson";
import { ZodError } from "zod";

import type { dbClient } from "@kan/db/client";
import { createDrizzleClient } from "@kan/db/client";
import { createLogger } from "@kan/logger";
import { createSupabaseServerClientFromHeaders } from "./lib/supabase";

const log = createLogger("api");

const TRPC_STATUS_MAP: Partial<Record<TRPCError["code"], number>> = {
  PARSE_ERROR: 400,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  METHOD_NOT_SUPPORTED: 405,
  TIMEOUT: 408,
  CONFLICT: 409,
  PRECONDITION_FAILED: 412,
  PAYLOAD_TOO_LARGE: 413,
  UNPROCESSABLE_CONTENT: 422,
  TOO_MANY_REQUESTS: 429,
  CLIENT_CLOSED_REQUEST: 499,
  INTERNAL_SERVER_ERROR: 500,
  NOT_IMPLEMENTED: 501,
  BAD_GATEWAY: 502,
  SERVICE_UNAVAILABLE: 503,
  GATEWAY_TIMEOUT: 504,
};

export interface User {
  id: string;
  name: string;
  email: string;
  emailVerified: boolean;
  createdAt: Date;
  updatedAt: Date;
  image?: string | null | undefined;
  stripeCustomerId?: string | null | undefined;
}

// Helper to get user from Supabase session
const getSupabaseUser = async (headers: Headers): Promise<User | null> => {
  const supabase = createSupabaseServerClientFromHeaders(headers);
  const { data: { user }, error } = await supabase.auth.getUser();
  
  if (error || !user) {
    return null;
  }

  return {
    id: user.id,
    name: user.user_metadata?.name ?? user.email?.split("@")[0] ?? "User",
    email: user.email ?? "",
    emailVerified: user.email_confirmed_at != null,
    createdAt: new Date(user.created_at),
    updatedAt: new Date(user.updated_at ?? user.created_at),
    image: user.user_metadata?.avatar_url ?? null,
    stripeCustomerId: null,
  };
};

interface CreateContextOptions {
  user: User | null | undefined;
  db: dbClient;
  headers: Headers;
  transport?: "trpc" | "rest";
}

export const createInnerTRPCContext = (opts: CreateContextOptions) => {
  return {
    user: opts.user,
    db: opts.db,
    headers: opts.headers,
    transport: opts.transport ?? "trpc",
    requestId: randomUUID(),
  };
};

export const createTRPCContext = async ({ req }: CreateNextContextOptions) => {
  const db = createDrizzleClient();
  const headers = new Headers(req.headers as Record<string, string>);
  const user = await getSupabaseUser(headers);

  return createInnerTRPCContext({
    db,
    user,
    headers,
    transport: "trpc",
  });
};

export const createNextApiContext = async (req: NextApiRequest) => {
  const db = createDrizzleClient();
  const headers = new Headers(req.headers as Record<string, string>);
  const user = await getSupabaseUser(headers);

  return createInnerTRPCContext({
    db,
    user,
    headers,
    transport: "trpc",
  });
};

export const createRESTContext = async ({ req }: CreateNextContextOptions) => {
  const db = createDrizzleClient();
  const headers = new Headers(req.headers as Record<string, string>);
  
  let user = null;
  try {
    user = await getSupabaseUser(headers);
  } catch (error) {
    log.warn({ err: error }, "Failed to get session, treating as unauthenticated");
  }

  return createInnerTRPCContext({
    db,
    user,
    headers,
    transport: "rest",
  });
};

const t = initTRPC
  .context<typeof createTRPCContext>()
  .meta<OpenApiMeta>()
  .create({
    transformer: superjson,
    errorFormatter({ shape, error }) {
      return {
        ...shape,
        data: {
          ...shape.data,
          zodError:
            error.cause instanceof ZodError ? error.cause.flatten() : null,
        },
      };
    },
  });

export const createTRPCRouter = t.router;

export const createCallerFactory = t.createCallerFactory;

const loggingMiddleware = t.middleware(async ({ path, type, next, ctx, getRawInput }) => {
  const start = Date.now();
  const [result, input] = await Promise.all([next(), getRawInput().catch(() => undefined)]);
  const duration = Date.now() - start;

  const { user, transport, requestId } = ctx as {
    user?: { id: string; email: string };
    transport?: string;
    requestId?: string;
  };
  const isCloud = process.env.NEXT_PUBLIC_KAN_ENV === "cloud";
  const meta = {
    requestId,
    procedure: path,
    type,
    transport,
    duration,
    userId: user?.id,
    ...(isCloud && { email: user?.email }),
    input,
  };

  const label = transport === "rest" ? "REST" : "tRPC";

  if (result.ok) {
    log.info({ ...meta, status: 200 }, `${label} OK`);
  } else {
    const status = TRPC_STATUS_MAP[result.error.code] ?? 500;
    const errorCode = result.error.code;
    log.error(
      { ...meta, status, errorCode, err: result.error },
      `${label} error`,
    );
  }

  return result;
});

export const publicProcedure = t.procedure.use(loggingMiddleware);

const enforceUserIsAuthed = t.middleware(async ({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: "UNAUTHORIZED" });
  }

  return next({
    ctx,
  });
});

const enforceUserIsAdmin = t.middleware(async ({ ctx, next }) => {
  if (ctx.headers.get("x-admin-api-key") !== env("KAN_ADMIN_API_KEY")) {
    throw new TRPCError({ code: "UNAUTHORIZED" });
  }

  return next({
    ctx,
  });
});

export const protectedProcedure = t.procedure
  .use(loggingMiddleware)
  .use(enforceUserIsAuthed);

export const adminProtectedProcedure = t.procedure
  .use(loggingMiddleware)
  .use(enforceUserIsAdmin)
  .meta({
    openapi: {
      method: "GET",
      path: "/admin/protected",
    },
  });
