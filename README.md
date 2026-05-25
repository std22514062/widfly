# Widfly

Kişisel uçuş fiyat takibi: **rota + tarih** kaydet, **Skyscanner** üzerinden en düşük fiyatı **WebKit** ile oku, **iPhone widget**’ında göster.

> Skyscanner scraping kişisel kullanım içindir. Site yapısı veya bot koruması değişirse scraper güncellenmelidir. Captcha görürsen bir süre bekleyip uygulamadan tekrar dene.

## Gereksinimler

- macOS + **Xcode** (App Store, ücretsiz)
- iPhone (iOS 17+)
- Ücretsiz Apple ID ile cihaza yükleme (7 günde bir Xcode’dan yenileme gerekebilir)

## Kurulum

### 1) Xcode projesi oluştur

[XcodeGen](https://github.com/yonaskolb/XcodeGen) yoksa:

```bash
brew install xcodegen
```

Proje klasöründe:

```bash
cd /Users/cagataykalayci/Desktop/widfly
xcodegen generate
open Widfly.xcodeproj
```

### 2) Signing

Xcode → **Widfly** target → **Signing & Capabilities**:

- Team: kendi Apple ID’n
- **App Groups** → `group.com.widfly.shared` (hem uygulama hem widget’ta aynı)

Aynı ayarı **WidflyWidgetExtension** için de yap.

### 3) iPhone’a yükle

iPhone’u bağla → üstten cihazı seç → **Run** (▶).

Ana ekranda widget ekle: **Widfly → Uçuş fiyatları**.

## Kullanım

1. **+** → kalkış / varış (IATA, örn. `IST`, `AMS`) + tarih → **Maks. süre** (varsayılan 8 sa.) → **Kaydet**
2. Listede **↻** ile tek rota, sol üstte **Tümünü yenile**
3. Yenileme sırasında Skyscanner sayfasının açıldığı bir **sheet** belirir:
   - Çoğu zaman fiyat çekilir çekilmez sheet kendi kendine kapanır
   - Skyscanner PerimeterX captcha gösterirse onu **sen çözersin** (slider / press & hold). Çözüldüğü an scraper fiyatı yakalar ve sheet kapanır
   - Aynı oturumda sonraki rotalar genellikle captcha istemez (cookie ~1 saat geçerli)
4. Widget, App Group’taki son kayıtlı fiyatları gösterir (uygulama yeniledikten sonra)

### Süre filtresi

Her rota için “maksimum toplam uçuş süresi” (aktarmalar dahil) tanımlanır. Skyscanner sonuç kartları DOM’dan tek tek okunur ve sınırı aşan uçuşlar fiyat hesabına dahil edilmez — sadece sınır içindeki en düşük fiyat seçilir.

## Mac’te scraper testi (isteğe bağlı)

Aynı scraper kodu Mac’te de çalışır; pencerede açılır, captcha varsa sen çözersin:

```bash
cd /Users/cagataykalayci/Desktop/widfly
swift run widfly-scraper IST AMS 2026-06-15
swift run widfly-scraper IST AMS 2026-06-15 --max-hours 8
swift run widfly-scraper IST AMS 2026-06-15 --headless --max-hours 10
```

## Mimari

| Parça | Görev |
|--------|--------|
| `WidflyKit` | Modeller, dosya deposu, Skyscanner URL, **WKWebView** scraper |
| `Widfly` (iOS) | Form, liste, yenileme |
| `WidflyWidget` | Kayıtlı rotaları widget’ta gösterir |

Fiyat mantığı: Skyscanner arama sayfası açılır → DOM’dan hem süre hem fiyat içeren “ticket card”lar bulunur → toplam süresi sınırı aşan kartlar elenir → kalanlar arasından **en düşük** fiyat alınır.

## Sınırlamalar

- Widget kendi başına Skyscanner’a gitmez; fiyat **uygulama içinde yenilendiğinde** güncellenir
- İlk yenilemede PerimeterX captcha çıkması beklenen davranıştır — sheet açıkken sen çözersin, sonraki rotalar otomatik geçer
- Skyscanner HTML/JS değişirse `SkyscannerWebScraper.swift` güncellenmeli

## Lisans

Kişisel kullanım. Skyscanner verilerine ilişkin site koşullarına uygun kullan.
