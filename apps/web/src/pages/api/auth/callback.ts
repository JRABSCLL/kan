import { createClientFromRequest } from "../../../lib/supabase/server";
import type { NextApiRequest, NextApiResponse } from "next";

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  const code = req.query.code as string | undefined;
  const next = (req.query.next as string) || "/";

  if (code) {
    const supabase = createClientFromRequest(req, res);
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    
    if (!error) {
      return res.redirect(307, next);
    }
  }

  return res.redirect(307, "/auth/error");
}
