import { createClient } from "@/shared/lib/supabase/server";

/**
 * Google OAuth 로그인 URL 생성
 * Supabase Auth + Google Calendar scope 통합
 * PRD B안: OAuth 한 번으로 로그인 + 캘린더 연동 동시 처리
 */
export async function getGoogleOAuthUrl(redirectTo?: string) {
  const supabase = await createClient();

  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: {
      redirectTo: redirectTo ?? `${process.env.NEXT_PUBLIC_SITE_URL}/callback`,
      scopes: "https://www.googleapis.com/auth/calendar.readonly",
      queryParams: {
        access_type: "offline", // refresh_token 발급을 위해 필수
        prompt: "consent", // 매번 동의 화면 표시 → refresh_token 보장
      },
    },
  });

  if (error) {
    throw new Error(`OAuth URL generation failed: ${error.message}`);
  }

  return data.url;
}
