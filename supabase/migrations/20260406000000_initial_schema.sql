-- ============================================================
-- WhenToMeet MVP 1차 — 초기 스키마
-- PRD v2.2 기반: 소셜 로그인 + 게스트 하이브리드
-- ============================================================

-- 커스텀 타입 정의
create type scheduling_status as enum ('open', 'confirmed', 'cancelled');
create type participant_status as enum ('pending', 'completed');
create type input_method as enum ('calendar', 'timetable', 'manual', 'ics');
create type calendar_provider as enum ('google', 'apple');
create type slot_source as enum ('calendar', 'timetable', 'manual', 'ics');
create type analysis_status as enum ('pending', 'processing', 'completed', 'failed');

-- ============================================================
-- 1. profiles: auth.users 확장 + 게스트 지원
-- ============================================================
-- 소셜 로그인 사용자: id = auth.users.id, is_guest = false
-- 게스트 사용자: id = 자체 생성 UUID, is_guest = true
-- 게스트→회원 전환: anonymous_id로 매칭 후 profile 머지

create table profiles (
  id uuid primary key default gen_random_uuid(),
  anonymous_id uuid unique,                          -- 게스트 세션 UUID (브라우저 발급)
  display_name text,
  avatar_url text,
  is_guest boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table profiles is '사용자 프로필 (소셜 로그인 + 게스트 하이브리드)';
comment on column profiles.anonymous_id is '게스트 세션 식별용 UUID. 회원 전환 시 머지 키로 사용';

-- ============================================================
-- 2. scheduling_groups: 일정 잡기 그룹
-- ============================================================
-- 호스트가 생성, share_code로 참여자 초대
-- PRD: 제목, 예상 소요시간, 후보 날짜 범위

create table scheduling_groups (
  id uuid primary key default gen_random_uuid(),
  host_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text,
  duration_minutes int not null default 60,          -- 예상 소요시간
  date_range_start date not null,                    -- 후보 날짜 시작
  date_range_end date not null,                      -- 후보 날짜 끝
  time_range_start time not null default '09:00',    -- 하루 중 검색 시작
  time_range_end time not null default '22:00',      -- 하루 중 검색 끝
  share_code text not null unique default encode(gen_random_bytes(6), 'hex'),
  status scheduling_status not null default 'open',
  confirmed_start timestamptz,                       -- 확정된 시작 시간
  confirmed_end timestamptz,                         -- 확정된 종료 시간
  created_at timestamptz not null default now(),

  constraint valid_date_range check (date_range_end >= date_range_start),
  constraint valid_time_range check (time_range_end > time_range_start)
);

comment on table scheduling_groups is 'PRD 3.1: 호스트가 생성하는 일정 잡기 그룹';

-- ============================================================
-- 3. participants: 그룹 참여자
-- ============================================================
-- PRD 3.2/3.3: 연동 참여자 + 비연동(수동) 참여자 모두 포함

create table participants (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references scheduling_groups(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  status participant_status not null default 'pending',
  input_method input_method,                         -- 어떤 방식으로 가용시간 입력했는지
  joined_at timestamptz not null default now(),

  unique (group_id, profile_id)                      -- 한 그룹에 같은 사용자 중복 참여 방지
);

comment on table participants is 'PRD 5.2: 참여자별 연동 상태 추적 (완료/대기 중)';

-- ============================================================
-- 4. calendar_connections: OAuth 토큰 저장
-- ============================================================
-- Google OAuth 통합 방식: Supabase Auth 로그인 시 provider_refresh_token 캡처
-- PRD 4.1: 캘린더 내용은 저장하지 않고, 가용/불가용 여부만 추출

create table calendar_connections (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  provider calendar_provider not null,
  access_token text not null,
  refresh_token text,
  token_expires_at timestamptz,
  calendar_id text default 'primary',                -- 연동된 캘린더 ID
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (profile_id, provider)                      -- 프로바이더당 1개 연동
);

comment on table calendar_connections is 'PRD 4.1: OAuth 토큰. 캘린더 내용 자체는 저장 안 함';

-- ============================================================
-- 5. availability_slots: 가용/불가 시간 슬롯
-- ============================================================
-- PRD 4.6: 모든 소스(캘린더/시간표/수동/.ics)의 통합 가용시간
-- is_available: calendar/timetable/ics → false(막힌 시간), manual → true(가능한 시간)

create table availability_slots (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references participants(id) on delete cascade,
  slot_start timestamptz not null,
  slot_end timestamptz not null,
  is_available boolean not null,                     -- true=가능, false=불가
  source slot_source not null,
  created_at timestamptz not null default now(),

  constraint valid_slot check (slot_end > slot_start)
);

comment on table availability_slots is 'PRD 4.6: 통합 가용시간. 교집합 = 공통 가능 시간대';

-- 매칭 쿼리 성능을 위한 인덱스
create index idx_slots_participant on availability_slots(participant_id);
create index idx_slots_time_range on availability_slots(slot_start, slot_end);

-- ============================================================
-- 6. timetable_images: 에브리타임 등 이미지 업로드
-- ============================================================
-- PRD 4.2/4.3: 이미지 업로드 → Gemini Vision 분석 → 블록 인식
-- 에브리타임뿐 아니라 학원·근무표·알바 등 모든 시간표 이미지 범용 지원

create table timetable_images (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  storage_path text not null,                        -- Supabase Storage 경로
  analysis_status analysis_status not null default 'pending',
  analysis_result jsonb,                             -- Gemini 분석 결과 (블록 위치)
  created_at timestamptz not null default now()
);

comment on table timetable_images is 'PRD 4.2: 시간표 이미지. 학기 중 1회 업로드 후 재사용';

-- ============================================================
-- 유틸: updated_at 자동 갱신 트리거
-- ============================================================

create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at
  before update on profiles
  for each row execute function update_updated_at();

create trigger calendar_connections_updated_at
  before update on calendar_connections
  for each row execute function update_updated_at();

create trigger scheduling_groups_updated_at
  before update on scheduling_groups
  for each row execute function update_updated_at();
