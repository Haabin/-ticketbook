-- TICKET BOOK · 사용자 의견(feedback) 테이블
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 전체를 붙여 넣고 Run 을 누르세요.
-- 여러 번 실행해도 안전해요. 기존 records 테이블이나 posters 버킷은 건드리지 않아요.
--
-- 규칙
--  · 누구나(로그인 안 한 사람 포함) 의견을 '쓰기'만 할 수 있어요.
--  · 읽기·수정·삭제 정책이 없어서 사이트에서는 아무도 의견을 볼 수 없어요.
--    (대시보드의 Table Editor 는 관리자 권한이라 RLS 와 상관없이 보여요.)

-- 1) 테이블 ------------------------------------------------------------------
create table if not exists public.feedback (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  kind        text not null,
  message     text not null,
  email       text,
  page        text not null default '기타',
  device      text not null default '컴퓨터',
  -- 로그인한 사람이면 자동으로 그 사람 id, 아니면 비어 있어요. (화면에서 직접 넣을 수 없어요)
  user_id     uuid default auth.uid() references auth.users (id) on delete set null
);

-- 2) 값 제한 (check 제약) -----------------------------------------------------
-- 다시 실행해도 되도록 지웠다가 다시 만들어요.
alter table public.feedback drop constraint if exists feedback_kind_check;
alter table public.feedback add constraint feedback_kind_check
  check (kind in ('좋아요', '불편해요', '이런 기능 있었으면', '오류 신고'));

alter table public.feedback drop constraint if exists feedback_message_check;
alter table public.feedback add constraint feedback_message_check
  check (char_length(btrim(message)) between 1 and 1000 and char_length(message) <= 1000);

alter table public.feedback drop constraint if exists feedback_email_check;
alter table public.feedback add constraint feedback_email_check
  check (email is null or (char_length(email) <= 200 and email ~ '^[^@[:space:]]+@[^@[:space:]]+$'));

alter table public.feedback drop constraint if exists feedback_page_check;
alter table public.feedback add constraint feedback_page_check
  check (page in ('공책', '다 같이 보기', '기록 수정', '기타'));

alter table public.feedback drop constraint if exists feedback_device_check;
alter table public.feedback add constraint feedback_device_check
  check (device in ('휴대폰', '컴퓨터'));

create index if not exists feedback_created_idx on public.feedback (created_at desc);

-- 3) 권한: 쓰기만, 그것도 정해진 칸만 ------------------------------------------
-- id, created_at, user_id 는 DB 가 채워요. 화면에서 다른 사람 user_id 를 넣을 수 없어요.
revoke all on table public.feedback from anon, authenticated;
grant insert (kind, message, email, page, device) on table public.feedback to anon, authenticated;

-- 4) RLS: insert 정책 하나만 --------------------------------------------------
alter table public.feedback enable row level security;

drop policy if exists "feedback: anyone can insert" on public.feedback;
create policy "feedback: anyone can insert" on public.feedback
  for insert to anon, authenticated
  with check (user_id is not distinct from (select auth.uid()));

-- select / update / delete 정책은 일부러 만들지 않아요 → 아무도 읽거나 고칠 수 없어요.
