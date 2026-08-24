create extension if not exists pgcrypto;

create table public.villages (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 100),
  join_code text not null unique check (join_code ~ '^[A-Z0-9]{6}$'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  village_id uuid not null references public.villages(id) on delete cascade,
  full_name text not null check (char_length(full_name) between 2 and 100),
  role text not null check (role in ('mukhtar', 'villager')),
  created_at timestamptz not null default now()
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  village_id uuid not null references public.villages(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 140),
  body text not null check (char_length(body) between 2 and 2000),
  type text not null default 'Genel',
  created_at timestamptz not null default now()
);

create table public.requests (
  id uuid primary key default gen_random_uuid(),
  village_id uuid not null references public.villages(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 140),
  description text not null default '' check (char_length(description) <= 2000),
  category text not null default 'Diğer',
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index announcements_village_created_idx on public.announcements(village_id, created_at desc);
create index requests_village_created_idx on public.requests(village_id, created_at desc);
create index profiles_village_idx on public.profiles(village_id);

create or replace function public.current_village_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select village_id from public.profiles where id = auth.uid()
$$;

create or replace function public.is_current_mukhtar()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select role = 'mukhtar' from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.generate_join_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.villages where join_code = candidate);
  end loop;
  return candidate;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text := coalesce(new.raw_user_meta_data ->> 'role', 'villager');
  target_village_id uuid;
  entered_code text;
begin
  if requested_role = 'mukhtar' then
    if char_length(trim(coalesce(new.raw_user_meta_data ->> 'village_name', ''))) < 2 then
      raise exception 'Geçerli bir köy adı gereklidir';
    end if;

    insert into public.villages(name, join_code, created_by)
    values (trim(new.raw_user_meta_data ->> 'village_name'), public.generate_join_code(), new.id)
    returning id into target_village_id;
  else
    requested_role := 'villager';
    entered_code := upper(trim(coalesce(new.raw_user_meta_data ->> 'join_code', '')));
    select id into target_village_id from public.villages where join_code = entered_code;
    if target_village_id is null then
      raise exception 'Katılım kodu geçersiz';
    end if;
  end if;

  insert into public.profiles(id, village_id, full_name, role)
  values (new.id, target_village_id, trim(coalesce(new.raw_user_meta_data ->> 'full_name', 'Kullanıcı')), requested_role);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.fill_record_scope()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.village_id := public.current_village_id();
  new.created_by := auth.uid();
  return new;
end;
$$;

create trigger announcements_fill_scope before insert on public.announcements
  for each row execute procedure public.fill_record_scope();
create trigger requests_fill_scope before insert on public.requests
  for each row execute procedure public.fill_record_scope();

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger requests_touch_updated_at before update on public.requests
  for each row execute procedure public.touch_updated_at();

create or replace function public.current_app_user()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id,
    'full_name', p.full_name,
    'role', p.role,
    'village_id', p.village_id,
    'village_name', v.name,
    'join_code', case when p.role = 'mukhtar' then v.join_code else '' end
  )
  from public.profiles p
  join public.villages v on v.id = p.village_id
  where p.id = auth.uid()
$$;

create or replace function public.village_members_for_current_user()
returns table(id uuid, full_name text, role text, created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.full_name, p.role, p.created_at
  from public.profiles p
  where p.village_id = public.current_village_id()
    and public.is_current_mukhtar()
  order by p.role, p.full_name
$$;

alter table public.villages enable row level security;
alter table public.profiles enable row level security;
alter table public.announcements enable row level security;
alter table public.requests enable row level security;

create policy "village members read village" on public.villages
  for select to authenticated using (id = public.current_village_id());

create policy "members read profiles in own village" on public.profiles
  for select to authenticated using (village_id = public.current_village_id());

create policy "members read announcements" on public.announcements
  for select to authenticated using (village_id = public.current_village_id());
create policy "mukhtar creates announcements" on public.announcements
  for insert to authenticated with check (village_id = public.current_village_id() and created_by = auth.uid() and public.is_current_mukhtar());
create policy "mukhtar updates announcements" on public.announcements
  for update to authenticated using (village_id = public.current_village_id() and public.is_current_mukhtar());
create policy "mukhtar deletes announcements" on public.announcements
  for delete to authenticated using (village_id = public.current_village_id() and public.is_current_mukhtar());

create policy "users read allowed requests" on public.requests
  for select to authenticated using (
    village_id = public.current_village_id()
    and (created_by = auth.uid() or public.is_current_mukhtar())
  );
create policy "villagers create requests" on public.requests
  for insert to authenticated with check (
    village_id = public.current_village_id()
    and created_by = auth.uid()
    and not public.is_current_mukhtar()
  );
create policy "mukhtar updates requests" on public.requests
  for update to authenticated using (village_id = public.current_village_id() and public.is_current_mukhtar())
  with check (village_id = public.current_village_id() and public.is_current_mukhtar());

revoke all on table public.villages, public.profiles, public.announcements, public.requests from anon, authenticated;
grant select on table public.villages, public.profiles, public.announcements, public.requests to authenticated;
grant insert on table public.announcements, public.requests to authenticated;
grant update, delete on table public.announcements to authenticated;
grant update(status) on table public.requests to authenticated;

revoke all on function public.current_app_user() from public;
revoke all on function public.village_members_for_current_user() from public;
grant execute on function public.current_app_user() to authenticated;
grant execute on function public.village_members_for_current_user() to authenticated;

alter publication supabase_realtime add table public.announcements;
alter publication supabase_realtime add table public.requests;
