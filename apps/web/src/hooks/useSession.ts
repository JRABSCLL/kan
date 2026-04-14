import { useEffect, useState } from "react";
import type { User } from "@supabase/supabase-js";
import { createClient } from "~/lib/supabase/client";

interface SessionUser {
  id: string;
  name: string;
  email: string;
  emailVerified: boolean;
  image?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

interface Session {
  user: SessionUser;
}

interface UseSessionReturn {
  data: Session | null;
  isPending: boolean;
  error: Error | null;
}

function mapSupabaseUser(user: User): SessionUser {
  return {
    id: user.id,
    name: user.user_metadata?.name ?? user.email?.split("@")[0] ?? "User",
    email: user.email ?? "",
    emailVerified: user.email_confirmed_at != null,
    image: user.user_metadata?.avatar_url ?? null,
    createdAt: new Date(user.created_at),
    updatedAt: new Date(user.updated_at ?? user.created_at),
  };
}

export function useSession(): UseSessionReturn {
  const [data, setData] = useState<Session | null>(null);
  const [isPending, setIsPending] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const supabase = createClient();

    // Get initial session
    const getSession = async () => {
      try {
        const { data: { user }, error: userError } = await supabase.auth.getUser();
        
        if (userError) {
          setError(userError);
          setData(null);
        } else if (user) {
          setData({ user: mapSupabaseUser(user) });
        } else {
          setData(null);
        }
      } catch (err) {
        setError(err instanceof Error ? err : new Error("Failed to get session"));
        setData(null);
      } finally {
        setIsPending(false);
      }
    };

    getSession();

    // Listen for auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (session?.user) {
          setData({ user: mapSupabaseUser(session.user) });
        } else {
          setData(null);
        }
        setIsPending(false);
      }
    );

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  return { data, isPending, error };
}

// Export signOut helper
export async function signOut() {
  const supabase = createClient();
  await supabase.auth.signOut();
  window.location.href = "/auth/login";
}
