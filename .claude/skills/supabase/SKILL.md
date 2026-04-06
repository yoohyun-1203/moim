---
name: supabase
description: Supabase 데이터베이스, 인증, RLS, Edge Functions, 서버 사이드 데이터 접근 작업 시 자동 활성화됩니다. Next.js App Router와의 통합 패턴을 적용합니다.
---

# Supabase 엔지니어

## 활성화 조건

- 데이터베이스 스키마 설계 및 마이그레이션
- Row Level Security (RLS) 정책 작성
- Supabase Auth 연동 (소셜 로그인, 이메일 인증)
- Server Actions / Route Handlers에서 데이터 접근
- Edge Functions (Deno) 개발
- Realtime 구독 설정
- Storage 버킷 관리

## 아키텍처 패턴

```
Server Component / Server Action → createServerClient → Supabase (RLS 적용)
Client Component → createBrowserClient → Supabase (RLS 적용)
Edge Function (Deno) → createClient → Supabase (service_role 가능)
```

### 데이터 접근 레이어
- `lib/supabase/server.ts`: Server-side 클라이언트 (쿠키 기반 세션)
- `lib/supabase/client.ts`: Browser-side 클라이언트
- `lib/supabase/middleware.ts`: 세션 갱신 미들웨어
- `supabase/migrations/`: SQL 마이그레이션 파일

### 인증 레이어
- Supabase Auth + `@supabase/ssr` 쿠키 기반 세션
- `middleware.ts`에서 세션 자동 갱신
- Server Component: `supabase.auth.getUser()`
- Client Component: `onAuthStateChange` 리스너

### 보안 레이어 (RLS)
- 모든 테이블에 RLS 활성화 필수
- `auth.uid()` 기반 정책으로 데이터 접근 제어
- `service_role` 키는 Edge Functions에서만 사용

## Thinking Cycle (필수)

모든 작업에 사고 사이클을 적용한다. 상세: `../_shared/resources/thinking-cycle.md`

1. **질문**: 실행 전 최소 1개 소크라테스 질문 → 답변 전 진행 금지
2. **결정**: 트레이드오프 존재 시 선택지 제시 → 근거 있는 선택 요구
3. **실행**: Phase 0, 1 완료 후에만 진입
4. **코드 스터디**: 변경 코드 이해도 점검 (레벨 S 기본)
5. **회고**: 작업 완료 후 사용자 회고 → `.claude/reflections/YYYY-MM-DD.md`에 기록

## 핵심 규칙

1. **RLS 우선**: 모든 테이블은 RLS 활성화, anon/authenticated 역할별 정책 정의
2. **서버/클라이언트 분리**: `createServerClient`(Server Components, Server Actions, Route Handlers) vs `createBrowserClient`(Client Components)
3. **타입 안전성**: `supabase gen types typescript`로 생성된 타입 사용, 수동 타입 정의 금지
4. **마이그레이션 관리**: `supabase migration new` → SQL 작성 → `supabase db push`
5. **환경 변수**: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`만 클라이언트 노출
6. **에러 처리**: Supabase 쿼리는 항상 `{ data, error }` 디스트럭처링, error 체크 필수
7. **N+1 방지**: 관계 데이터는 `.select('*, related_table(*)')` 조인 사용

## 코드 품질

- TypeScript strict mode
- 생성된 DB 타입: `src/types/database.types.ts`
- SQL 마이그레이션: 명확한 파일명 (`YYYYMMDDHHMMSS_description.sql`)
- RLS 정책: 테이블당 최소 SELECT/INSERT/UPDATE/DELETE 각 1개

## 실행 절차

1. 요구사항 분석 및 데이터 모델링
2. SQL 마이그레이션 작성 (테이블 + RLS 정책)
3. 타입 생성 (`supabase gen types typescript`)
4. Supabase 클라이언트 유틸 구현 (server/client)
5. Server Actions 또는 Route Handlers 구현
6. 테스트 작성 및 검증
7. 체크리스트 확인 후 완료 보고

## 파일 구조 규칙

```
src/
├── lib/supabase/
│   ├── server.ts          # createServerClient 래퍼
│   ├── client.ts          # createBrowserClient 래퍼
│   └── middleware.ts       # 세션 갱신 로직
├── types/
│   └── database.types.ts   # supabase gen types 출력
├── app/
│   ├── (auth)/             # 인증 관련 라우트 그룹
│   │   ├── login/
│   │   ├── signup/
│   │   └── callback/       # OAuth 콜백
│   └── api/                # Route Handlers (필요 시)
supabase/
├── migrations/             # SQL 마이그레이션
├── seed.sql                # 시드 데이터
└── config.toml             # Supabase 로컬 설정
```
