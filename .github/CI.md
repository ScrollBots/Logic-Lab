# خط لولهٔ CI و انتشار خودکار (Logic Lab)

هدف اصلی پروژه اپلیکیشن اندروید است. تست‌ها و بیلد روی **GitHub Actions** اجرا می‌شوند و اجرای محلی آن‌ها ضروری نیست.
یک push معمولی به `main` فقط CI را اجرا می‌کند؛ انتشار امضاشده به تگ نسخه یا اجرای دستی گردش کار Release نیاز دارد.

| فایل | کار |
|------|-----|
| `.github/workflows/ci.yml` | اعتبارسنجی گردش‌کارها، بررسی فرمت، تحلیل ایستا، همهٔ تست‌های واحد و ویجت و سپس بیلد اندروید APK/AAB |
| `.github/workflows/release.yml` | دروازهٔ کیفیت مستقل و سپس بیلد امضاشده، بررسی بسته‌ها و انتشار GitHub Release |
| `.github/workflows/web-preview.yml` | پیش‌نمایش اختیاری وب؛ بخشی از مسیر انتشار اندروید نیست |
| `.github/dependabot.yml` | پیشنهاد به‌روزرسانی اکشن‌ها و بسته‌های Dart |
| `tool/validate_ci.dart` | بررسی YAML گردش‌کارها و وجود اسکریپت‌های ارجاع‌شده |
| `tool/set_version.dart` | هماهنگ‌کردن نسخهٔ `pubspec.yaml` و ثابت‌های `lib/core/app_info.dart` |

## ۱. محیط اجرای CI

* Flutter **3.29.3**، Dart **3.7.2** و runner از نوع `ubuntu-latest`.
* `flutter pub get` پیش از تحلیل، تست و بیلد اجرا می‌شود.
* CI روی push و pull request به `main` و همچنین با اجرای دستی فعال است.
* Release با تگ `v*` یا ورودی نسخه در اجرای دستی فعال می‌شود.
* شکست فرمت، تحلیل یا هر تست، job کیفیت را ناموفق می‌کند. هیچ‌یک از jobهای بیلد یا انتشار از `always()` یا `continue-on-error` برای عبور از این شکست استفاده نمی‌کنند.

## ۲. اسرار امضای اندروید

چهار Secret زیر باید در `Settings → Secrets and variables → Actions` موجود باشند:

| نام Secret | مقدار |
|------------|-------|
| `ANDROID_KEYSTORE_BASE64` | محتوای keystore به‌صورت base64 |
| `ANDROID_KEYSTORE_PASSWORD` | رمز keystore |
| `ANDROID_KEY_ALIAS` | نام alias کلید، مثلاً `upload` |
| `ANDROID_KEY_PASSWORD` | رمز کلید |

برای ایجاد کلید اولیه:

```bash
keytool -genkeypair -v -keystore ~/logic-lab-upload.jks -keyalg RSA \
        -keysize 2048 -validity 10000 -alias upload
base64 -w0 ~/logic-lab-upload.jks > logic-lab-upload.jks.b64
```

keystore، رمزها و فایل base64 را در مخزن قرار ندهید. برای به‌روزرسانی اپ نصب‌شده، همان کلید امضای نسخه‌های قبلی را حفظ کنید؛ کلید تازه تولید نکنید.
`android/key.properties` و فایل‌های `*.jks` در `.gitignore` هستند. Release فایل‌ها را فقط روی runner از Secretها بازیابی می‌کند.

## ۳. روند CI اندروید

```text
push / pull_request به main یا اجرای دستی
        │
        ├─ quality
        │    ├─ dart run tool/validate_ci.dart
        │    ├─ dart format --output=none --set-exit-if-changed lib test tool
        │    ├─ flutter analyze --no-pub
        │    └─ flutter test --no-pub --coverage --reporter expanded
        │
        └─ build  [needs: quality]
             ├─ flutter build apk --debug --no-pub
             ├─ flutter build appbundle --release --no-pub
             └─ بررسی برچسب و نسخهٔ APK
```

تمام تست‌های موجود اجرا می‌شوند؛ تعداد تست‌ها در مستندات ثابت نگه داشته نمی‌شود.
گزارش `coverage/lcov.info`، APK دیباگ و AAB به‌صورت artifact با ماندگاری ۱۴ روز قابل دریافت‌اند.
آپلود گزارش پوشش حتی هنگام شکست تست‌ها تلاش می‌شود، اما این کار اجازهٔ اجرای بیلد را نمی‌دهد.
خروجی CI تست دود است و جای خروجی امضاشدهٔ Release را نمی‌گیرد؛ بدون تنظیمات امضای release، Gradle از کلید debug استفاده می‌کند.

## ۴. انتشار نسخهٔ جدید

نمونهٔ انتشار `1.2.0`:

```bash
# نسخهٔ منبع و صفحهٔ درباره را هماهنگ کنید؛ build باید از نسخهٔ قبلی بزرگ‌تر باشد.
dart run tool/set_version.dart 1.2.0+3

# تغییرات و مستندات را کامیت و push کنید.
git push origin main

# فقط پس از موفقیت CI تگ نسخه را ارسال کنید.
git tag -a v1.2.0 -m "Logic Lab 1.2.0"
git push origin v1.2.0
```

گردش کار Release:

1. job مستقل `quality`، اعتبارسنجی YAML، بررسی فرمت، تحلیل ایستا و **همهٔ تست‌ها** را روی همان commit اجرا می‌کند.
2. job `release` با `needs: quality` فقط در صورت موفقیت آن شروع می‌شود.
3. نسخه از تگ یا ورودی اجرای دستی خوانده می‌شود؛ `tool/set_version.dart` نسخه را در `pubspec.yaml` و `AppInfo` هماهنگ می‌کند. شمارهٔ build در بستهٔ انتشار برابر `github.run_number` گردش کار Release است.
4. تست `test/core/app_info_test.dart` دوباره اجرا می‌شود تا هماهنگی نسخهٔ اعمال‌شده تأیید شود.
5. keystore بازیابی و `android/key.properties` ساخته می‌شود.
6. APKهای امضاشدهٔ `arm64-v8a`، `armeabi-v7a` و `x86_64` و یک AAB ساخته می‌شوند.
7. مشخصات APKها بررسی می‌شود؛ نام لانچر باید **Logic Lab** باشد.
8. فایل‌ها روی GitHub Release منتشر می‌شوند؛ نسخه‌های دارای پسوند پیش‌انتشار با برچسب prerelease ثبت می‌شوند.

اجرای دستی: `Actions → Release → Run workflow` و وارد کردن نسخهٔ SemVer بدون پیشوند `v`.
این مسیر نیز همان دروازهٔ کیفیت را دارد. تگ نسخه‌های منتشرشده را جابه‌جا نکنید و برای انتشار بعدی نسخهٔ تازه انتخاب کنید.

## ۵. پیش‌نمایش وب

وب هدف اصلی محصول نیست و برای تست یا انتشار اندروید لازم نیست.
گردش کار موجود پیش‌نمایش تنها وقتی متغیر `ENABLE_WEB_PREVIEW` برابر `true` باشد روی push اجرا می‌شود؛ اجرای دستی آن نیز ممکن است.
فقط در صورت نیاز به این پیش‌نمایش، GitHub Pages را روی منبع `GitHub Actions` تنظیم کنید. داده‌های نسخهٔ وب در حافظه‌اند و ماندگاری SQLite اندروید را ندارند.

## ۶. عیب‌یابی

| مشکل | اقدام |
|------|-------|
| بیلد یا انتشار skipped است | ابتدا خطای job `quality` را در log رفع کنید؛ گیت تست را دور نزنید. |
| Secret امضا موجود نیست | چهار نام جدول اسرار را بررسی کنید؛ مقدارها را در log چاپ نکنید. |
| خطای امضا | `storeFile` باید به `upload-keystore.jks` در پوشهٔ `android` اشاره کند و رمزها/alias با همان کلید قبلی مطابقت داشته باشند. |
| نسخهٔ صفحهٔ درباره با بسته متفاوت است | `tool/set_version.dart` و خروجی تست `app_info_test.dart` را بررسی کنید؛ `AppInfo` ثابت‌های همگام با `pubspec.yaml` دارد، نه خواندن فایل در زمان اجرای برنامه. |
| خطای فرمت | فایل‌های گزارش‌شده در مرحلهٔ `Check code formatting` را با Dart 3.7.2 قالب‌بندی کنید. |
| خطای تحلیل یا تست | log همان مرحله را بخوانید و اصلاح را در یک کامیت جدید ارسال کنید. |
| نیاز به تست شاخه‌های دیگر | فیلتر `on.push.branches` در `ci.yml` را متناسب با نیاز تغییر دهید. |

نسخهٔ Flutter در `env.FLUTTER_VERSION` گردش‌کارها ثابت شده است؛ هنگام ارتقا، آن‌ها را هماهنگ تغییر دهید.
موفقیت تست‌های واحد/ویجت و بیلد CI، جای بررسی لمسی، عملکرد و haptic روی دستگاه واقعی اندروید را نمی‌گیرد.
