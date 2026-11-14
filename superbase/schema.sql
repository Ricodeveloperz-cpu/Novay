-- Nova AI v2.1: jalankan di Supabase Dashboard > SQL Editor.
-- Aman dijalankan ulang: tabel, index, policy, function, dan trigger dibuat idempotent.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now()
);

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Percakapan baru',
  messages jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  model text not null,
  created_at timestamptz not null default now()
);

create index if not exists chats_user_updated_idx on public.chats(user_id, updated_at desc);
create index if not exists ai_usage_user_created_idx on public.ai_usage(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.chats enable row level security;
alter table public.ai_usage enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can read own chats" on public.chats;
drop policy if exists "Users can insert own chats" on public.chats;
drop policy if exists "Users can update own chats" on public.chats;
drop policy if exists "Users can delete own chats" on public.chats;
drop policy if exists "Users can read own usage" on public.ai_usage;

create policy "Users can read own profile" on public.profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "Users can read own chats" on public.chats for select using (auth.uid() = user_id);
create policy "Users can insert own chats" on public.chats for insert with check (auth.uid() = user_id);
create policy "Users can update own chats" on public.chats for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete own chats" on public.chats for delete using (auth.uid() = user_id);
create policy "Users can read own usage" on public.ai_usage for select using (auth.uid() = user_id);

-- Reservasi kuota atomik; setiap request yang diterima mengonsumsi satu slot.
create or replace function public.reserve_ai_usage(p_user_id uuid, p_model text, p_daily_limit integer)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  used_count integer;
begin
  if p_user_id is null or p_model is null or p_daily_limit < 1 then
    return false;
  end if;

  -- Serialize reservation per user agar dua request bersamaan tidak melewati limit.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));
  select count(*)::integer into used_count
  from public.ai_usage
  where user_id = p_user_id
    and created_at >= (date_trunc('day', now() at time zone 'utc') at time zone 'utc');

  if used_count >= p_daily_limit then
    return false;
  end if;

  insert into public.ai_usage(user_id, model) values (p_user_id, p_model);
  return true;
end;
$$;

revoke all on function public.reserve_ai_usage(uuid, text, integer) from public, anon, authenticated;
grant execute on function public.reserve_ai_usage(uuid, text, integer) to service_role;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();
