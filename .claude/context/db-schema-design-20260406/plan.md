# DB 스키마 + Google Calendar OAuth 설계

## 목표
PRD v2.2 기반 MVP 1차 DB 스키마 설계 및 Google Calendar OAuth 연동 구현

## 성공 기준
1. 모든 테이블에 RLS 활성화 및 정책 정의
2. 호스트/참여자(연동+비연동) 플로우를 커버하는 스키마
3. 게스트 → 회원 머지 가능한 구조
4. Google Calendar OAuth 플로우 동작
5. `pnpm build` 통과

## 범위

### In
- users 테이블 (소셜 로그인 + 게스트 세션)
- scheduling_groups (일정 잡기)
- participants (참여자)
- calendar_connections (캘린더 연동 정보)
- availability_slots (가용시간)
- timetable_images (에브리타임 등 이미지)
- RLS 정책
- Google Calendar OAuth 플로우

### Out
- Apple CalDAV 연동 (Phase 2)
- Gemini Vision 이미지 분석 (별도 작업)
- 카카오톡 공유 API
- 카카오 소셜 로그인

## 마일스톤
1. DB 스키마 SQL 마이그레이션 작성
2. RLS 정책 작성
3. Supabase 타입 생성
4. Google Calendar OAuth 구현
