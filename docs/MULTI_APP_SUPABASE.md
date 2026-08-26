# Aynı Supabase projesine yeni uygulama ekleme

Bu projede `auth.users` ortaktır. Uygulamaya özel bütün veriler `app_id` ile
ayrılır; aynı kullanıcı birden fazla uygulamada farklı role sahip olabilir.

## 1. Uygulama kaydı oluştur

Yeni bir UUID üretip kayıt ekleyin:

```sql
insert into public.apps (id, slug, name)
values ('YENI-UUID', 'uygulama_slug', 'Uygulama Adı');
```

UUID uygulamanın kaynak kodunda sabit `appId` değeri olarak tutulur. UUID gizli
değildir; yetkilendirme anahtarı olarak kullanılmaz.

## 2. Üyelik oluştur

Kullanıcı uygulamaya katıldığında güvenilir bir veritabanı fonksiyonu veya sunucu
işlemi şu kaydı oluşturmalıdır:

```sql
insert into public.app_memberships(app_id, user_id, display_name, role)
values ('YENI-UUID', auth.uid(), 'Ad Soyad', 'user');
```

İstemciye doğrudan `app_memberships` yazma yetkisi verilmemelidir. Her uygulama
kendi onboarding fonksiyonunu kullanmalıdır.

## 3. Her alan tablosuna app_id ekle

Uygulamaya ait tablolarda aşağıdaki desen kullanılmalıdır:

```sql
app_id uuid not null references public.apps(id) on delete cascade
```

Sorgular `app_id` ile filtrelenmeli, benzersiz alanlar mümkünse bileşik olmalıdır:

```sql
unique (app_id, external_code)
```

## 4. RLS zorunluluğu

Her tablo için RLS açılmalı ve politika hem `app_id` hem üyeliği doğrulamalıdır:

```sql
alter table public.example_records enable row level security;

create policy "members read own app records"
on public.example_records
for select to authenticated
using (
  exists (
    select 1
    from public.app_memberships membership
    where membership.app_id = example_records.app_id
      and membership.user_id = auth.uid()
  )
);
```

`app_id` tek başına güvenlik sağlamaz; tahmin edilebilir/public bir kimliktir.
Güvenlik her zaman RLS ve kullanıcı üyeliğiyle sağlanmalıdır.

## 5. Flutter isteği

Kayıt metadata'sında ve uygulamaya ait veri eklemelerinde sabit kimliği gönderin:

```dart
const appId = 'YENI-UUID';

await supabase.auth.signUp(
  email: email,
  password: password,
  data: {'app_id': appId},
);

await supabase.from('example_records').insert({
  'app_id': appId,
  'title': 'Örnek',
});
```

RPC fonksiyonlarında `p_app_id` parametresi kullanılmalı ve üyelik sunucu tarafında
yeniden doğrulanmalıdır.
