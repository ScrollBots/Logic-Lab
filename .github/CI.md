# خط لولهٔ CI و انتشار خودکار (Logic Lab)

این پروژه با **GitHub Actions** ساخته شده است تا بعد از هر `push`، بدون نیاز به تست روی سیستم
شخصی، کد به‌صورت خودکار بررسی، ساخته و منتشر شود.

| فایل | کار |
|------|-----|
| `.github/workflows/ci.yml` | دروازهٔ کیفیت: `dart format` + `flutter analyze` + `flutter test` + یک بیلد واقعی اندروید (APK + AAB) به‌عنوان تست دود |
| `.github/workflows/release.yml` | با زدن تگ نسخه، بیلد **امضاشده**، بررسی مشخصات بسته و انتشار روی GitHub Release |
| `.github/workflows/web-preview.yml` | انتشار نسخهٔ وب روی GitHub Pages برای مرور سریع رابط کاربری |
| `.github/dependabot.yml` | به‌روزرسانی خودکار اکشن‌های گیت‌هاب و پکیج‌های Dart |
| `tool/validate_ci.dart` | اعتبارسنجی خودِ فایل‌های YAML و وجود اسکریپت‌های引用شده (در خود CI اجرا می‌شود) |
| `tool/set_version.dart` | تنظیم نسخه در `pubspec.yaml` از روی تگ انتشار |

---

## ۱. راه‌اندازی یک‌باره در GitHub

۱. یک ریپازیتوری **Private** (یا Public) با نام دلخواه بسازید.
۲. پروژه را به ریپازیتوری وصل کنید:

```bash
git remote add origin https://github.com/<user>/<repo>.git
git push -u origin main
```

۳. در `Settings → Pages → Source` مقدار **GitHub Actions** را انتخاب کنید (برای پیش‌نمایش وب).

---

## ۲. اسکریت‌های لازم (Secrets)

برای انتشار امضاشده، این چهار Secret را در
`Settings → Secrets and variables → Actions → New repository secret` بسازید:

| نام Secret | مقدار |
|------------|-------|
| `ANDROID_KEYSTORE_BASE64` | محتوای فایل keystore به‌صورت base64 |
| `ANDROID_KEYSTORE_PASSWORD` | رمز ذخیرهٔ keystore |
| `ANDROID_KEY_ALIAS` | نام alias (مثال: `upload`) |
| `ANDROID_KEY_PASSWORD` | رمز کلید |

ساخت keystore (یک‌بار برای همیشه) و base64 کردن آن:

```bash
keytool -genkeypair -v -keystore ~/logic-lab-upload.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload

base64 -w0 ~/logic-lab-upload.jks > logic-lab-upload.jks.b64
# محتوای فایل .b64 را در ANDROID_KEYSTORE_BASE64 بگذارید
```

> ⚠️ این فایل keystore را در هیچ ریپازیتوری (حتی Private) قرار ندهید.
> `android/key.properties` و `*.jks` در `.gitignore` هستند.

---

## ۳. انتشار یک نسخهٔ جدید

```bash
# 1. تغییرات را push کنید و منتظر سبز شدن CI شوید
git push origin main

# 2. نسخه را تگ بزنید (شماره باید SemVer باشد)
git tag v1.1.0
git push origin v1.1.0
```

workflow انتشار به‌صورت خودکار:

1. نسخه را از روی تگ می‌خواند و در `pubspec.yaml` می‌نویسد
   (شمارهٔ build = شمارهٔ اجرای workflow).
2. keystore را از Secretها بازیابی و `android/key.properties` را می‌سازد.
3. سه APK مجزای `arm64-v8a`، `armeabi-v7a` و `x86_64` به‌علاوهٔ یک AAB می‌سازد.
4. نام و نسخهٔ بسته را با `aapt2` بررسی می‌کند (اگر برچسب «Logic Lab» نباشد، build شکست می‌خورد).
5. همهٔ فایل‌ها را روی یک **GitHub Release** منتشر می‌کند.

انتشار دستی هم ممکن است است: `Actions → Release → Run workflow` و وارد کردن نسخه.

---

## ۴. چه چیزی در هر `push` اجرا می‌شود؟

```
push / pull_request
        │
        ├─► job: quality
        │     ├─ dart format --set-exit-if-changed   (قالب‌بندی)
        │     ├─ flutter analyze                     (تحلیل ایستا)
        │     ├─ flutter test --coverage              (۱۴۹ تست)
        │     └─ tool/validate_ci.dart               (اعتبارسنجی خود CI)
        │
        └─► job: build  (فقط اگر quality سبز شود)
              ├─ flutter build apk --debug
              ├─ flutter build appbundle --release
              └─ بررسی برچسب و نسخهٔ APK
```

خروجی‌ها (APK/AAB و گزارش پوشش) به‌صورت **artifact** در هر اجرای workflow قابل دانلود هستند.

---

## ۵. نکات و عیب‌یابی

| مشکل | راه‌حل |
|------|---------|
| `ANDROID_KEYSTORE_BASE64` خالی است | Secretها را درست ساخته‌اید؟ نام‌ها باید دقیقاً مطابق جدول بالا باشد. |
| خطای امضا | `storeFile` در `key.properties` باید به فایل keystore اشاره کند؛ CI آن را در `android/upload-keystore.jks` می‌گذارد. |
| نسخه در About با تگ نمی‌خواند | `AppInfo` از `pubspec.yaml` می‌خواند و یک تست CI این هم‌خوانی را بررسی می‌کند. |
| `pub get` کند است | اکشن Flutter از کش Pub استفاده می‌کند؛ در صورت نیاز `flutter-action` را با `cache: true` نگه دارید (پیش‌فرض همین است). |
| می‌خواهم روی هر برانچ تست شود | در `ci.yml` بخش `on.push.branches` را تغییر دهید یا خط `branches` را حذف کنید. |

نسخهٔ Flutter در `env.FLUTTER_VERSION` فایل‌های workflow قفل شده است (هم‌راستا با نسخهٔ
محلی `3.29.3`). اگر Flutter را ارتقا دادید، همان عدد را در هر سه workflow تغییر دهید.
