-- Shared Supabase project: application registry and tenant isolation.
create table public.apps (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9_-]{1,62}$'),
  name text not null check (char_length(name) between 2 and 100),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.apps(id, slug, name)
values ('44ec1e7b-9def-47c8-beaf-2c11d1807d14', 'muhtarim', 'Muhtarım');

create table public.app_memberships (
  app_id uuid not null references public.apps(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 100),
  role text not null check (char_length(role) between 2 and 50),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (app_id, user_id)
);

alter table public.villages add column app_id uuid;
alter table public.village_profiles add column app_id uuid;
alter table public.announcements add column app_id uuid;
alter table public.requests add column app_id uuid;

update public.villages set app_id = '44ec1e7b-9def-47c8-beaf-2c11d1807d14';
update public.village_profiles set app_id = '44ec1e7b-9def-47c8-beaf-2c11d1807d14';
update public.announcements set app_id = '44ec1e7b-9def-47c8-beaf-2c11d1807d14';
update public.requests set app_id = '44ec1e7b-9def-47c8-beaf-2c11d1807d14';

alter table public.villages alter column app_id set not null;
alter table public.village_profiles alter column app_id set not null;
alter table public.announcements alter column app_id set not null;
alter table public.requests alter column app_id set not null;

alter table public.villages add constraint villages_app_id_fkey
  foreign key (app_id) references public.apps(id) on delete cascade;
alter table public.village_profiles add constraint village_profiles_app_id_fkey
  foreign key (app_id) references public.apps(id) on delete cascade;
alter table public.announcements add constraint announcements_app_id_fkey
  foreign key (app_id) references public.apps(id) on delete cascade;
alter table public.requests add constraint requests_app_id_fkey
  foreign key (app_id) references public.apps(id) on delete cascade;

insert into public.app_memberships(app_id, user_id, display_name, role)
select app_id, id, full_name, role from public.village_profiles;

-- A user may belong to multiple apps; membership identity is composite.
alter table public.announcements drop constraint announcements_created_by_fkey;
alter table public.requests drop constraint requests_created_by_fkey;
alter table public.village_profiles drop constraint village_profiles_village_id_fkey;
alter table public.announcements drop constraint announcements_village_id_fkey;
alter table public.requests drop constraint requests_village_id_fkey;
alter table public.village_profiles drop constraint village_profiles_pkey;

alter table public.villages add constraint villages_app_id_id_key unique (app_id, id);
alter table public.village_profiles add constraint village_profiles_pkey primary key (app_id, id);
alter table public.village_profiles add constraint village_profiles_app_user_fkey
  foreign key (app_id, id) references public.app_memberships(app_id, user_id) on delete cascade;
alter table public.village_profiles add constraint village_profiles_app_village_fkey
  foreign key (app_id, village_id) references public.villages(app_id, id) on delete cascade;
alter table public.announcements add constraint announcements_app_village_fkey
  foreign key (app_id, village_id) references public.villages(app_id, id) on delete cascade;
alter table public.requests add constraint requests_app_village_fkey
  foreign key (app_id, village_id) references public.villages(app_id, id) on delete cascade;
alter table public.announcements add constraint announcements_app_creator_fkey
  foreign key (app_id, created_by) references public.village_profiles(app_id, id) on delete cascade;
alter table public.requests add constraint requests_app_creator_fkey
  foreign key (app_id, created_by) references public.village_profiles(app_id, id) on delete cascade;

alter table public.villages drop constraint villages_join_code_key;
alter table public.villages add constraint villages_app_join_code_key unique (app_id, join_code);

create index villages_app_idx on public.villages(app_id);
create index village_profiles_app_village_idx on public.village_profiles(app_id, village_id);
create index announcements_app_created_idx on public.announcements(app_id, created_at desc);
create index requests_app_created_idx on public.requests(app_id, created_at desc);

drop policy "village members read village" on public.villages;
drop policy "members read profiles in own village" on public.village_profiles;
drop policy "members read announcements" on public.announcements;
drop policy "mukhtar creates announcements" on public.announcements;
drop policy "mukhtar updates announcements" on public.announcements;
drop policy "mukhtar deletes announcements" on public.announcements;
drop policy "users read allowed requests" on public.requests;
drop policy "villagers create requests" on public.requests;
drop policy "mukhtar updates requests" on public.requests;

drop function public.muhtarim_current_app_user();
drop function public.muhtarim_village_members_for_current_user();

create or replace function public.muhtarim_current_village_id(p_app_id uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select village_id from public.village_profiles
  where app_id = p_app_id and id = auth.uid()
$$;

create or replace function public.muhtarim_is_current_mukhtar(p_app_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select role = 'mukhtar' from public.village_profiles
    where app_id = p_app_id and id = auth.uid()), false)
$$;

create or replace function public.muhtarim_generate_join_code(p_app_id uuid)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare candidate text;
begin
  loop
    candidate := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (
      select 1 from public.villages where app_id = p_app_id and join_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

create or replace function public.muhtarim_handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  muhtarim_app_id constant uuid := '44ec1e7b-9def-47c8-beaf-2c11d1807d14';
  requested_app_id text := new.raw_user_meta_data ->> 'app_id';
  requested_role text := coalesce(new.raw_user_meta_data ->> 'role', 'villager');
  requested_name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', 'Kullanıcı'));
  target_village_id uuid;
  entered_code text;
begin
  -- Other apps in the same project use their own app-specific onboarding.
  if requested_app_id is distinct from muhtarim_app_id::text then return new; end if;
  if requested_role not in ('mukhtar', 'villager') then requested_role := 'villager'; end if;

  insert into public.app_memberships(app_id, user_id, display_name, role)
  values (muhtarim_app_id, new.id, requested_name, requested_role);

  if requested_role = 'mukhtar' then
    if char_length(trim(coalesce(new.raw_user_meta_data ->> 'village_name', ''))) < 2 then
      raise exception 'Geçerli bir köy adı gereklidir';
    end if;
    insert into public.villages(app_id, name, join_code, created_by)
    values (muhtarim_app_id, trim(new.raw_user_meta_data ->> 'village_name'),
      public.muhtarim_generate_join_code(muhtarim_app_id), new.id)
    returning id into target_village_id;
  else
    entered_code := upper(trim(coalesce(new.raw_user_meta_data ->> 'join_code', '')));
    select id into target_village_id from public.villages
    where app_id = muhtarim_app_id and join_code = entered_code;
    if target_village_id is null then raise exception 'Katılım kodu geçersiz'; end if;
  end if;

  insert into public.village_profiles(app_id, id, village_id, full_name, role)
  values (muhtarim_app_id, new.id, target_village_id, requested_name, requested_role);
  return new;
end;
$$;

create or replace function public.muhtarim_fill_record_scope()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.app_id is distinct from '44ec1e7b-9def-47c8-beaf-2c11d1807d14'::uuid then
    raise exception 'Geçersiz uygulama kimliği';
  end if;
  new.village_id := public.muhtarim_current_village_id(new.app_id);
  new.created_by := auth.uid();
  if new.village_id is null then raise exception 'Bu uygulama için köy üyeliği bulunamadı'; end if;
  return new;
end;
$$;

drop function public.muhtarim_current_village_id();
drop function public.muhtarim_is_current_mukhtar();
drop function public.muhtarim_generate_join_code();

create or replace function public.muhtarim_current_app_user(p_app_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id, 'app_id', p.app_id, 'full_name', p.full_name, 'role', p.role,
    'village_id', p.village_id, 'village_name', v.name,
    'join_code', case when p.role = 'mukhtar' then v.join_code else '' end
  )
  from public.village_profiles p
  join public.villages v on v.app_id = p.app_id and v.id = p.village_id
  where p.app_id = p_app_id and p.id = auth.uid()
$$;

create or replace function public.muhtarim_village_members_for_current_user(p_app_id uuid)
returns table(id uuid, full_name text, role text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.id, p.full_name, p.role, p.created_at from public.village_profiles p
  where p.app_id = p_app_id
    and p.village_id = public.muhtarim_current_village_id(p_app_id)
    and public.muhtarim_is_current_mukhtar(p_app_id)
  order by p.role, p.full_name
$$;

alter table public.apps enable row level security;
alter table public.app_memberships enable row level security;
create policy "active apps are readable" on public.apps
  for select to anon, authenticated using (is_active);
create policy "users read own app memberships" on public.app_memberships
  for select to authenticated using (user_id = auth.uid());

create policy "app village members read village" on public.villages
  for select to authenticated using (id = public.muhtarim_current_village_id(app_id));
create policy "app members read village profiles" on public.village_profiles
  for select to authenticated using (village_id = public.muhtarim_current_village_id(app_id));
create policy "app members read announcements" on public.announcements
  for select to authenticated using (village_id = public.muhtarim_current_village_id(app_id));
create policy "app mukhtar creates announcements" on public.announcements
  for insert to authenticated with check (
    village_id = public.muhtarim_current_village_id(app_id)
    and created_by = auth.uid() and public.muhtarim_is_current_mukhtar(app_id));
create policy "app mukhtar updates announcements" on public.announcements
  for update to authenticated using (
    village_id = public.muhtarim_current_village_id(app_id)
    and public.muhtarim_is_current_mukhtar(app_id));
create policy "app mukhtar deletes announcements" on public.announcements
  for delete to authenticated using (
    village_id = public.muhtarim_current_village_id(app_id)
    and public.muhtarim_is_current_mukhtar(app_id));
create policy "users read allowed app requests" on public.requests
  for select to authenticated using (
    village_id = public.muhtarim_current_village_id(app_id)
    and (created_by = auth.uid() or public.muhtarim_is_current_mukhtar(app_id)));
create policy "app villagers create requests" on public.requests
  for insert to authenticated with check (
    village_id = public.muhtarim_current_village_id(app_id)
    and created_by = auth.uid() and not public.muhtarim_is_current_mukhtar(app_id));
create policy "app mukhtar updates requests" on public.requests
  for update to authenticated using (
    village_id = public.muhtarim_current_village_id(app_id)
    and public.muhtarim_is_current_mukhtar(app_id))
  with check (village_id = public.muhtarim_current_village_id(app_id)
    and public.muhtarim_is_current_mukhtar(app_id));

revoke all on table public.apps, public.app_memberships from anon, authenticated;
grant select on table public.apps to anon, authenticated;
grant select on table public.app_memberships to authenticated;
revoke all on function public.muhtarim_current_village_id(uuid) from public;
revoke all on function public.muhtarim_is_current_mukhtar(uuid) from public;
revoke all on function public.muhtarim_generate_join_code(uuid) from public;
revoke all on function public.muhtarim_current_app_user(uuid) from public;
revoke all on function public.muhtarim_village_members_for_current_user(uuid) from public;
grant execute on function public.muhtarim_current_village_id(uuid) to authenticated;
grant execute on function public.muhtarim_is_current_mukhtar(uuid) to authenticated;
grant execute on function public.muhtarim_current_app_user(uuid) to authenticated;
grant execute on function public.muhtarim_village_members_for_current_user(uuid) to authenticated;
