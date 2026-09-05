alter table public.villages add column province text not null default '';
alter table public.villages add column district text not null default '';

update public.villages
set name = 'Kırklar Köyü', province = 'Aydın', district = 'Efeler'
where app_id = '44ec1e7b-9def-47c8-beaf-2c11d1807d14';

create table public.work_posts (
  id uuid primary key default gen_random_uuid(),
  app_id uuid not null references public.apps(id) on delete cascade,
  village_id uuid not null,
  created_by uuid not null,
  title text not null check (char_length(title) between 2 and 140),
  body text not null check (char_length(body) between 2 and 3000),
  image_path text not null check (char_length(image_path) between 5 and 500),
  location text not null default '',
  is_demo boolean not null default false,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint work_posts_app_village_fkey
    foreign key (app_id, village_id)
    references public.villages(app_id, id) on delete cascade,
  constraint work_posts_app_creator_fkey
    foreign key (app_id, created_by)
    references public.village_profiles(app_id, id) on delete cascade
);

create index work_posts_app_village_created_idx
  on public.work_posts(app_id, village_id, created_at desc);

create or replace function public.muhtarim_fill_work_post_scope()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.app_id is distinct from '44ec1e7b-9def-47c8-beaf-2c11d1807d14'::uuid then
    raise exception 'Geçersiz uygulama kimliği';
  end if;
  new.village_id := public.muhtarim_current_village_id(new.app_id);
  new.created_by := auth.uid();
  if new.village_id is null then
    raise exception 'Bu uygulama için köy üyeliği bulunamadı';
  end if;
  return new;
end;
$$;

create trigger muhtarim_work_posts_fill_scope
before insert on public.work_posts
for each row execute procedure public.muhtarim_fill_work_post_scope();

alter table public.work_posts enable row level security;

create policy "app members read work posts" on public.work_posts
  for select to authenticated using (
    village_id = public.muhtarim_current_village_id(app_id)
  );
create policy "app mukhtar creates work posts" on public.work_posts
  for insert to authenticated with check (
    village_id = public.muhtarim_current_village_id(app_id)
    and created_by = auth.uid()
    and public.muhtarim_is_current_mukhtar(app_id)
  );
create policy "app mukhtar updates work posts" on public.work_posts
  for update to authenticated using (
    village_id = public.muhtarim_current_village_id(app_id)
    and public.muhtarim_is_current_mukhtar(app_id)
  );
create policy "app mukhtar deletes work posts" on public.work_posts
  for delete to authenticated using (
    village_id = public.muhtarim_current_village_id(app_id)
    and public.muhtarim_is_current_mukhtar(app_id)
  );

revoke all on table public.work_posts from anon, authenticated;
grant select, insert, update, delete on table public.work_posts to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values (
  'muhtarim-posts',
  'muhtarim-posts',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "village members read post images"
on storage.objects for select to authenticated
using (
  bucket_id = 'muhtarim-posts'
  and (storage.foldername(name))[1] = '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  and (storage.foldername(name))[2] = public.muhtarim_current_village_id(
    '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  )::text
);

create policy "mukhtar uploads post images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'muhtarim-posts'
  and (storage.foldername(name))[1] = '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  and (storage.foldername(name))[2] = public.muhtarim_current_village_id(
    '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  )::text
  and public.muhtarim_is_current_mukhtar(
    '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  )
);

create policy "mukhtar deletes post images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'muhtarim-posts'
  and (storage.foldername(name))[1] = '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  and (storage.foldername(name))[2] = public.muhtarim_current_village_id(
    '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  )::text
  and public.muhtarim_is_current_mukhtar(
    '44ec1e7b-9def-47c8-beaf-2c11d1807d14'
  )
);

create or replace function public.muhtarim_current_app_user(p_app_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p.id,
    'app_id', p.app_id,
    'full_name', p.full_name,
    'role', p.role,
    'village_id', p.village_id,
    'village_name', v.name,
    'province', v.province,
    'district', v.district,
    'join_code', case when p.role = 'mukhtar' then v.join_code else '' end
  )
  from public.village_profiles p
  join public.villages v on v.app_id = p.app_id and v.id = p.village_id
  where p.app_id = p_app_id and p.id = auth.uid()
$$;
