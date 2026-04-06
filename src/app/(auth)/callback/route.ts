import { NextResponse } from "next/server";
import { createClient } from "@/shared/lib/supabase/server";

/**
 * Google OAuth 콜백 핸들러
 * Supabase Auth가 리다이렉트한 code를 세션으로 교환하고,
 * provider_refresh_token을 calendar_connections에 저장한다.
 *
 * PRD B안: OAuth 연동 = 로그인 + 캘린더 연동 동시 처리
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/";

  if (!code) {
    return NextResponse.redirect(`${origin}/login?error=no_code`);
  }

  const supabase = await createClient();

  // code → session 교환
  const { data, error } = await supabase.auth.exchangeCodeForSession(code);

  if (error || !data.session) {
    return NextResponse.redirect(`${origin}/login?error=auth_failed`);
  }

  const { session } = data;

  // Google provider_refresh_token이 있으면 calendar_connections에 저장
  // (최초 로그인 시에만 refresh_token이 제공됨)
  if (session.provider_token && session.provider_refresh_token) {
    const { error: upsertError } = await supabase
      .from("calendar_connections")
      .upsert(
        {
          profile_id: session.user.id,
          provider: "google",
          access_token: session.provider_token,
          refresh_token: session.provider_refresh_token,
          token_expires_at: new Date(
            Date.now() + (session.expires_in ?? 3600) * 1000
          ).toISOString(),
          calendar_id: "primary",
        },
        { onConflict: "profile_id,provider" }
      );

    if (upsertError) {
      console.error("calendar_connections upsert failed:", upsertError);
    }
  }

  // profiles 테이블에 사용자 정보 upsert (is_guest = false)
  const user = session.user;
  await supabase.from("profiles").upsert(
    {
      id: user.id,
      display_name:
        user.user_metadata?.full_name ?? user.user_metadata?.name ?? null,
      avatar_url: user.user_metadata?.avatar_url ?? null,
      is_guest: false,
    },
    { onConflict: "id" }
  );

  return NextResponse.redirect(`${origin}${next}`);
}
