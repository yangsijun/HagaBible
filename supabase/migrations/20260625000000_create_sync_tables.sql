-- HagaBible device-sync mirror tables (Scenario A).
--
-- Mirrors the local GRDB user-data schema 1:1, MINUS the local-only `needs_sync`
-- flag. Timestamps are `double precision` (epoch seconds) to match the local
-- SQLite REAL columns exactly — no timezone parsing in the round-trip.
--
-- Identity / conflict keys:
--   bookmarks      -> primary key `id`              (many rows per chapter OK)
--   reading_marks  -> natural key (user_id, book_code, chapter), UNIQUE
--                     (`id` may differ between devices that marked the same
--                      chapter offline; the natural key is what converges)
--
-- RLS scopes every row to the signed-in user (auth.uid()). Deletes are soft
-- (deleted_at tombstone) and propagate as ordinary updated_at deltas; hard
-- DELETE is explicitly denied by policy.
--
-- Security: `user_id` is always server-assigned via DEFAULT auth.uid(). The
-- client must NOT include `user_id` in push payloads — PostgREST will use the
-- column default, and RLS WITH CHECK enforces it matches the session.
--
-- Security: `updated_at` is constrained to at most 24 h in the future to
-- prevent a malicious client from setting a far-future timestamp that
-- permanently wins every LWW conflict.

-- ============================================================ bookmarks
create table if not exists public.bookmarks (
    id          text primary key,
    book_code   text   not null,
    book_order  int    not null,
    chapter     int    not null,
    start_verse int    not null,
    end_verse   int    not null,
    color       text   not null,
    notes       text,
    created_at  double precision not null,
    updated_at  double precision not null
                    check (updated_at <= extract(epoch from now()) + 86400),
    deleted_at  double precision,
    user_id     uuid   not null default auth.uid()
);

create index if not exists idx_bookmarks_user_updated
    on public.bookmarks (user_id, updated_at);

alter table public.bookmarks enable row level security;

create policy "bookmarks_select_own" on public.bookmarks
    for select using (user_id = auth.uid());
create policy "bookmarks_insert_own" on public.bookmarks
    for insert with check (user_id = auth.uid());
create policy "bookmarks_update_own" on public.bookmarks
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "bookmarks_delete_deny" on public.bookmarks
    for delete using (false);

-- ============================================================ reading_marks
create table if not exists public.reading_marks (
    id          text primary key,
    book_code   text   not null,
    book_order  int    not null,
    chapter     int    not null,
    is_read     int    not null default 0,
    created_at  double precision not null,
    updated_at  double precision not null
                    check (updated_at <= extract(epoch from now()) + 86400),
    deleted_at  double precision,
    user_id     uuid   not null default auth.uid(),
    unique (user_id, book_code, chapter)
);

create index if not exists idx_reading_marks_user_updated
    on public.reading_marks (user_id, updated_at);

alter table public.reading_marks enable row level security;

create policy "reading_marks_select_own" on public.reading_marks
    for select using (user_id = auth.uid());
create policy "reading_marks_insert_own" on public.reading_marks
    for insert with check (user_id = auth.uid());
create policy "reading_marks_update_own" on public.reading_marks
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "reading_marks_delete_deny" on public.reading_marks
    for delete using (false);
