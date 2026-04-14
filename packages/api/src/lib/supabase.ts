import { createServerClient, type CookieOptions } from "@supabase/ssr";
import type { NextApiRequest, NextApiResponse } from "next";

export function createSupabaseServerClient(
  req: NextApiRequest,
  res?: NextApiResponse,
) {
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return req.cookies[name];
        },
        set(name: string, value: string, options: CookieOptions) {
          if (res) {
            res.setHeader("Set-Cookie", `${name}=${value}; Path=/; ${options.maxAge ? `Max-Age=${options.maxAge};` : ""} ${options.httpOnly ? "HttpOnly;" : ""} ${options.secure ? "Secure;" : ""} SameSite=Lax`);
          }
        },
        remove(name: string, options: CookieOptions) {
          if (res) {
            res.setHeader("Set-Cookie", `${name}=; Path=/; Max-Age=0`);
          }
        },
      },
    },
  );
}

export function createSupabaseServerClientFromHeaders(headers: Headers) {
  const cookieHeader = headers.get("cookie") ?? "";
  const cookies: Record<string, string> = {};
  
  cookieHeader.split(";").forEach((cookie) => {
    const [key, value] = cookie.trim().split("=");
    if (key && value) {
      cookies[key] = value;
    }
  });

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookies[name];
        },
        set() {
          // Can't set cookies from headers context
        },
        remove() {
          // Can't remove cookies from headers context
        },
      },
    },
  );
}
