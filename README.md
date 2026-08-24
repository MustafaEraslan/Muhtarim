# Muhtarım

Muhtar ile köy halkını tek bir dijital köy meydanında buluşturan Flutter uygulaması.

## MVP özellikleri

- Muhtar yeni bir köy hesabı açar ve 6 karakterli katılım kodu alır.
- Köy sakinleri katılım koduyla doğru köye dahil olur.
- Köy sakinleri su, yol, elektrik, temizlik ve diğer kategorilerde talep açar.
- Muhtar köydeki bütün talepleri görür; `Yeni`, `İşlemde`, `Çözüldü` olarak günceller.
- Muhtar düğün, hayır, çalışma, acil ve genel duyuru yayınlar.
- Muhtar köye katılan üyeleri listeler.
- Supabase RLS politikaları her köyün verisini diğer köylerden ayırır.

## Supabase kurulumu

1. Supabase Dashboard'da boş bir proje oluşturun.
2. SQL Editor'ü açıp `supabase/migrations/0001_initial_schema.sql` dosyasının tamamını çalıştırın.
3. Project Settings > API bölümündeki Project URL ve `anon` public key değerlerini alın.
4. Uygulamayı aşağıdaki gibi başlatın:

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://PROJE.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=ANON_KEY
```

Android üretim paketi:

```bash
flutter build appbundle \
  --dart-define=SUPABASE_URL=https://PROJE.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=ANON_KEY
```

`anon` key mobil uygulamada kullanılmak üzere tasarlanmıştır; `service_role` anahtarını hiçbir zaman uygulamaya eklemeyin.

## İlk kullanım

1. Kayıt ekranında `Muhtar` seçilerek köy adıyla ilk hesap açılır.
2. Muhtar, Profil veya Köylüler ekranındaki katılım kodunu köy halkıyla paylaşır.
3. Köy sakinleri `Köy sakini` seçeneği ve bu kodla hesap oluşturur.

Supabase Auth e-posta doğrulaması açıksa kullanıcı, giriş yapmadan önce gelen e-postadaki bağlantıyı açmalıdır. Hızlı yerel test için Dashboard > Authentication > Providers > Email altında doğrulama kapatılabilir.

## Kontroller

```bash
flutter analyze
flutter test
```

## Sonraki sürüm önerileri

- Firebase Cloud Messaging ile yeni duyuru ve talep durumu bildirimleri
- Talebe fotoğraf ve konum ekleme
- Telefon numarasıyla giriş ve yaşlı kullanıcılar için daha büyük yazı modu
- Duyuru zamanlama, anket ve aidat/bağış takibi
- Muhtar hesabı için belgeyle doğrulama ve yönetici onayı
