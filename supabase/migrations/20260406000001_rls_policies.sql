-- ============================================================
-- RLS 정책
-- 원칙: 모든 테이블 RLS 활성화, anon/authenticated 역할별 정의
-- ============================================================

-- RLS 활성화
alter table profiles enable row level security;
alter table scheduling_groups enable row level security;
alter table participants enable row level security;
alter table calendar_connections enable row level security;
alter table availability_slots enable row level security;
alter table timetable_images enable row level security;

-- ============================================================
-- profiles
-- ============================================================

-- 자기 프로필 조회 (로그인 사용자)
create policy "profiles_select_own"
  on profiles for select
  to authenticated
  using (id = auth.uid());

-- 같은 그룹 참여자의 display_name, avatar_url 조회 (실시간 현황용)
create policy "profiles_select_group_members"
  on profiles for select
  to authenticated
  using (
    id in (
      select p.profile_id from participants p
      where p.group_id in (
        select p2.group_id from participants p2
        where p2.profile_id = auth.uid()
      )
    )
  );

-- 자기 프로필 수정
create policy "profiles_update_own"
  on profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- 게스트 프로필 생성 (anonymous_id 기반)
create policy "profiles_insert_anon"
  on profiles for insert
  to anon
  with check (is_guest = true and anonymous_id is not null);

-- 게스트 자기 프로필 조회
create policy "profiles_select_anon"
  on profiles for select
  to anon
  using (is_guest = true);

-- ============================================================
-- scheduling_groups
-- ============================================================

-- 누구나 share_code로 그룹 조회 (링크 공유)
create policy "groups_select_by_share_code"
  on scheduling_groups for select
  to anon, authenticated
  using (true);

-- 로그인 사용자만 그룹 생성
create policy "groups_insert_authenticated"
  on scheduling_groups for insert
  to authenticated
  with check (host_id = auth.uid());

-- 호스트만 그룹 수정 (확정, 취소)
create policy "groups_update_host"
  on scheduling_groups for update
  to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

-- 호스트만 그룹 삭제
create policy "groups_delete_host"
  on scheduling_groups for delete
  to authenticated
  using (host_id = auth.uid());

-- ============================================================
-- participants
-- ============================================================

-- 같은 그룹 참여자끼리 조회 (실시간 현황: "5명 중 3명 완료")
create policy "participants_select_group"
  on participants for select
  to anon, authenticated
  using (true);

-- 로그인 사용자 참여
create policy "participants_insert_authenticated"
  on participants for insert
  to authenticated
  with check (profile_id = auth.uid());

-- 게스트 참여
create policy "participants_insert_anon"
  on participants for insert
  to anon
  with check (
    profile_id in (
      select id from profiles where is_guest = true
    )
  );

-- 자기 참여 정보 수정 (status 업데이트)
create policy "participants_update_own"
  on participants for update
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ============================================================
-- calendar_connections
-- ============================================================

-- 자기 연동 정보만 조회
create policy "calendar_select_own"
  on calendar_connections for select
  to authenticated
  using (profile_id = auth.uid());

-- 자기 연동 정보 생성
create policy "calendar_insert_own"
  on calendar_connections for insert
  to authenticated
  with check (profile_id = auth.uid());

-- 자기 연동 정보 수정 (토큰 갱신)
create policy "calendar_update_own"
  on calendar_connections for update
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- 자기 연동 정보 삭제 (연동 해제)
create policy "calendar_delete_own"
  on calendar_connections for delete
  to authenticated
  using (profile_id = auth.uid());

-- ============================================================
-- availability_slots
-- ============================================================

-- 같은 그룹 참여자의 슬롯 조회 (매칭 계산용)
create policy "slots_select_group"
  on availability_slots for select
  to anon, authenticated
  using (
    participant_id in (
      select id from participants
    )
  );

-- 자기 슬롯 생성 (로그인)
create policy "slots_insert_authenticated"
  on availability_slots for insert
  to authenticated
  with check (
    participant_id in (
      select id from participants where profile_id = auth.uid()
    )
  );

-- 게스트 슬롯 생성
create policy "slots_insert_anon"
  on availability_slots for insert
  to anon
  with check (
    participant_id in (
      select id from participants p
      join profiles pr on p.profile_id = pr.id
      where pr.is_guest = true
    )
  );

-- 자기 슬롯 삭제 (재입력 시)
create policy "slots_delete_own"
  on availability_slots for delete
  to authenticated
  using (
    participant_id in (
      select id from participants where profile_id = auth.uid()
    )
  );

-- ============================================================
-- timetable_images
-- ============================================================

-- 자기 이미지만 조회
create policy "timetable_select_own"
  on timetable_images for select
  to authenticated
  using (profile_id = auth.uid());

-- 자기 이미지 업로드
create policy "timetable_insert_own"
  on timetable_images for insert
  to authenticated
  with check (profile_id = auth.uid());

-- 자기 이미지 수정 (분석 결과 업데이트는 Edge Function에서 service_role로)
create policy "timetable_update_own"
  on timetable_images for update
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ============================================================
-- Realtime 활성화 (PRD 5: 실시간 현황 표시)
-- ============================================================

alter publication supabase_realtime add table participants;
alter publication supabase_realtime add table availability_slots;
