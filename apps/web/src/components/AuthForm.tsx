import { useSearchParams } from "next/navigation";
import { zodResolver } from "@hookform/resolvers/zod";
import { t } from "@lingui/core/macro";
import { Trans } from "@lingui/react/macro";
import { env } from "next-runtime-env";
import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import {
  FaApple,
  FaDiscord,
  FaGithub,
  FaGoogle,
} from "react-icons/fa";
import { z } from "zod";

import { createClient } from "~/lib/supabase/client";
import Button from "~/components/Button";
import Input from "~/components/Input";
import { usePopup } from "~/providers/popup";

type OAuthProvider = "google" | "github" | "discord" | "apple";

interface FormValues {
  name?: string;
  email: string;
  password?: string;
}

interface AuthProps {
  setIsMagicLinkSent: (value: boolean, recipient: string) => void;
  isSignUp?: boolean;
}

const EmailSchema = z.object({
  name: z.string().optional(),
  email: z.string().email(),
  password: z.string().min(6, "Password must be at least 6 characters").optional(),
});

const availableOAuthProviders = {
  google: {
    id: "google" as OAuthProvider,
    name: "Google",
    icon: FaGoogle,
  },
  github: {
    id: "github" as OAuthProvider,
    name: "GitHub",
    icon: FaGithub,
  },
  discord: {
    id: "discord" as OAuthProvider,
    name: "Discord",
    icon: FaDiscord,
  },
  apple: {
    id: "apple" as OAuthProvider,
    name: "Apple",
    icon: FaApple,
  },
};

export function Auth({ setIsMagicLinkSent, isSignUp }: AuthProps) {
  const [isLoginWithProviderPending, setIsLoginWithProviderPending] =
    useState<null | OAuthProvider>(null);
  const [isCredentialsEnabled, setIsCredentialsEnabled] = useState(false);
  const [isLoginWithEmailPending, setIsLoginWithEmailPending] = useState(false);
  const [loginError, setLoginError] = useState<string | null>(null);
  const { showPopup } = usePopup();

  const supabase = createClient();

  const redirect = useSearchParams().get("next");
  const callbackURL = redirect ?? "/boards";

  // Safely get environment variables on client side to avoid hydration mismatch
  useEffect(() => {
    const credentialsAllowed =
      env("NEXT_PUBLIC_ALLOW_CREDENTIALS")?.toLowerCase() === "true";
    setIsCredentialsEnabled(credentialsAllowed);
  }, []);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(EmailSchema),
  });

  const handleLoginWithEmail = async (
    email: string,
    password?: string | null,
    name?: string,
  ) => {
    setIsLoginWithEmailPending(true);
    setLoginError(null);
    
    if (!password) {
      setLoginError(t`Password is required.`);
      setIsLoginWithEmailPending(false);
      return;
    }

    const redirectUrl = process.env.NEXT_PUBLIC_DEV_SUPABASE_REDIRECT_URL ?? 
      `${window.location.origin}/api/auth/callback?next=${encodeURIComponent(callbackURL)}`;

    if (isSignUp) {
      const { error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: redirectUrl,
          data: {
            name: name ?? email.split("@")[0],
          },
        },
      });

      if (error) {
        setLoginError(error.message);
      } else {
        showPopup({
          header: t`Success`,
          message: t`Please check your email to confirm your account.`,
          icon: "success",
        });
        setIsMagicLinkSent(true, email);
      }
    } else {
      const { error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        setLoginError(error.message);
      } else {
        showPopup({
          header: t`Success`,
          message: t`You have been logged in successfully.`,
          icon: "success",
        });
        // Redirect to callback URL
        window.location.href = callbackURL;
      }
    }

    setIsLoginWithEmailPending(false);
  };

  const handleLoginWithProvider = async (provider: OAuthProvider) => {
    setIsLoginWithProviderPending(provider);
    setLoginError(null);

    const redirectUrl = process.env.NEXT_PUBLIC_DEV_SUPABASE_REDIRECT_URL ?? 
      `${window.location.origin}/api/auth/callback?next=${encodeURIComponent(callbackURL)}`;

    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: redirectUrl,
      },
    });

    setIsLoginWithProviderPending(null);

    if (error) {
      setLoginError(
        t`Failed to login with ${provider.charAt(0).toUpperCase() + provider.slice(1)}. Please try again.`,
      );
    }
  };

  const onSubmit = async (values: FormValues) => {
    await handleLoginWithEmail(values.email, values.password, values.name);
  };

  // Check which OAuth providers are available (based on env vars)
  const enabledProviders = Object.entries(availableOAuthProviders).filter(
    ([key]) => {
      // For now, show all providers - they'll fail gracefully if not configured
      return true;
    }
  );

  return (
    <div className="space-y-6">
      {enabledProviders.length > 0 && (
        <div className="space-y-2">
          {enabledProviders.map(([key, provider]) => (
            <Button
              key={key}
              onClick={() => handleLoginWithProvider(provider.id)}
              isLoading={isLoginWithProviderPending === provider.id}
              iconLeft={<provider.icon />}
              fullWidth
              size="lg"
            >
              <Trans>
                Continue with {provider.name}
              </Trans>
            </Button>
          ))}
        </div>
      )}
      
      {!isCredentialsEnabled && enabledProviders.length === 0 && (
        <div className="flex w-full items-center gap-4">
          <div className="h-[1px] w-1/3 bg-light-600 dark:bg-dark-600" />
          <span className="text-center text-sm text-light-900 dark:text-dark-900">
            {t`No authentication methods are currently available`}
          </span>
          <div className="h-[1px] w-1/3 bg-light-600 dark:bg-dark-600" />
        </div>
      )}
      
      {isCredentialsEnabled && (
        <form onSubmit={handleSubmit(onSubmit)}>
          {enabledProviders.length > 0 && (
            <div className="mb-[1.5rem] flex w-full items-center gap-4">
              <div className="h-[1px] w-full bg-light-600 dark:bg-dark-600" />
              <span className="text-sm text-light-900 dark:text-dark-900">
                {t`or`}
              </span>
              <div className="h-[1px] w-full bg-light-600 dark:bg-dark-600" />
            </div>
          )}
          <div className="space-y-2">
            {isSignUp && (
              <div>
                <Input
                  {...register("name")}
                  placeholder={t`Enter your name`}
                />
                {errors.name && (
                  <p className="mt-2 text-xs text-red-400">
                    {t`Please enter a valid name`}
                  </p>
                )}
              </div>
            )}
            <div>
              <Input
                {...register("email", { required: true })}
                placeholder={t`Enter your email address`}
              />
              {errors.email && (
                <p className="mt-2 text-xs text-red-400">
                  {t`Please enter a valid email address`}
                </p>
              )}
            </div>

            <div>
              <Input
                type="password"
                {...register("password", { required: true })}
                placeholder={t`Enter your password`}
              />
              {errors.password && (
                <p className="mt-2 text-xs text-red-400">
                  {errors.password.message ?? t`Please enter a valid password`}
                </p>
              )}
            </div>
            
            {loginError && (
              <p className="mt-2 text-xs text-red-400">{loginError}</p>
            )}
          </div>
          <div className="mt-[1.5rem] flex items-center gap-4">
            <Button
              type="submit"
              isLoading={isLoginWithEmailPending}
              fullWidth
              size="lg"
              variant="secondary"
            >
              {isSignUp ? t`Sign up` : t`Log in`}
            </Button>
          </div>
        </form>
      )}
      
      {!isCredentialsEnabled && loginError && (
        <p className="mt-2 text-xs text-red-400">{loginError}</p>
      )}
    </div>
  );
}
