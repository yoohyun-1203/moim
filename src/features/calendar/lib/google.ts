/**
 * Google Calendar API 유틸
 * PRD 4.1: 캘린더 내용은 저장하지 않고, 가용/불가용 여부만 추출
 */

interface GoogleEvent {
  start: { dateTime?: string; date?: string };
  end: { dateTime?: string; date?: string };
  transparency?: string; // "transparent" = 자유, "opaque" = 바쁨(기본값)
}

interface BusySlot {
  start: string; // ISO 8601
  end: string;
}

const GOOGLE_CALENDAR_API = "https://www.googleapis.com/calendar/v3";

/**
 * Google access token 갱신
 */
export async function refreshGoogleToken(refreshToken: string): Promise<{
  access_token: string;
  expires_in: number;
}> {
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: process.env.GOOGLE_CLIENT_ID!,
      client_secret: process.env.GOOGLE_CLIENT_SECRET!,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  if (!res.ok) {
    throw new Error(`Token refresh failed: ${res.status}`);
  }

  return res.json();
}

/**
 * 특정 기간의 바쁜 시간(busy slots)만 추출
 * PRD: 캘린더 내용 저장 안 함, 가용/불가용 여부만
 */
export async function getGoogleBusySlots(
  accessToken: string,
  calendarId: string,
  timeMin: string,
  timeMax: string
): Promise<BusySlot[]> {
  // FreeBusy API로 바쁜 시간만 조회 (이벤트 내용 노출 없음)
  const res = await fetch(`${GOOGLE_CALENDAR_API}/freeBusy`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      timeMin,
      timeMax,
      timeZone: "Asia/Seoul",
      items: [{ id: calendarId }],
    }),
  });

  if (!res.ok) {
    throw new Error(`FreeBusy query failed: ${res.status}`);
  }

  const data = await res.json();
  const calendar = data.calendars?.[calendarId];

  if (!calendar?.busy) {
    return [];
  }

  return calendar.busy.map((slot: { start: string; end: string }) => ({
    start: slot.start,
    end: slot.end,
  }));
}
