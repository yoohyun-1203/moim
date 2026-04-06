# 체크리스트

## DB 스키마
- [x] profiles 테이블 (auth.users 확장, 게스트 지원)
- [x] scheduling_groups 테이블 (일정 잡기 그룹)
- [x] participants 테이블 (그룹 참여자)
- [x] calendar_connections 테이블 (OAuth 토큰)
- [x] availability_slots 테이블 (가용/불가 시간)
- [x] timetable_images 테이블 (이미지 업로드 기록)
- [x] RLS 정책 전체 작성

## Google Calendar OAuth
- [x] Google OAuth 환경변수 설정
- [x] OAuth 콜백 Route Handler 작성
- [x] 토큰 저장/갱신 로직
- [x] 캘린더 이벤트 조회 유틸

## 검증
- [x] pnpm build 통과
- [ ] 마이그레이션 SQL 문법 검증 (Supabase 로컬 환경 필요)
