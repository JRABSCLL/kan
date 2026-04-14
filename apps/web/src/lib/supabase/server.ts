import { createServerClient, type CookieOptions } from "@supabase/ssr";
import type { NextApiRequest, NextApiResponse } from "next";
import type { IncomingMessage, ServerResponse } from "http";

// For API routes (Pages Router)
export function createClientFromRequest(
  req: NextApiRequest | IncomingMessage,
  res: NextApiResponse | ServerResponse
) {
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          const cookies: { name: string; value: string }[] = [];
          const cookieHeader = (req as NextApiRequest).cookies || {};
          
          // If req.cookies is available (NextApiRequest)
          if (typeof cookieHeader === "object" && !Array.isArray(cookieHeader)) {
            for (const [name, value] of Object.entries(cookieHeader)) {
              if (value) {
                cookies.push({ name, value });
              }
            }
          }
          
          return cookies;
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            const cookieValue = `${name}=${value}; Path=${options?.path || "/"}; ${
              options?.maxAge ? `Max-Age=${options.maxAge};` : ""
            } ${options?.httpOnly ? "HttpOnly;" : ""} ${
              options?.secure ? "Secure;" : ""
            } SameSite=${options?.sameSite || "Lax"}`;
            
            const existingCookies = (res as NextApiResponse).getHeader("Set-Cookie") || [];
            const cookies = Array.isArray(existingCookies)
              ? existingCookies
              : [existingCookies as string];
            (res as NextApiResponse).setHeader("Set-Cookie", [...cookies, cookieValue]);
          });
        },
      },
    }
  );
}

// For getServerSideProps
export function createClientFromContext(context: {
  req: IncomingMessage & { cookies: Partial<{ [key: string]: string }> };
  res: ServerResponse;
}) {
  return createClientFromRequest(context.req as NextApiRequest, context.res as NextApiResponse);
}
