# ⚡ Logic Lab

> آزمایشگاه منطق — شبیه‌ساز آفلاین و فارسی‌زبان مدارهای دیجیتال

[![Flutter](https://img.shields.io/badge/Flutter-3.29.3-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7.2-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://github.com/ScrollBots/Logic-Lab/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/ScrollBots/Logic-Lab/ci.yml?label=CI&logo=github)](https://github.com/ScrollBots/Logic-Lab/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ScrollBots/Logic-Lab?label=Release&logo=github)](https://github.com/ScrollBots/Logic-Lab/releases)

---

## 🎯 در یک نگاه

**Logic Lab** یک شبیه‌ساز مدارهای دیجیتال است که کاملاً **آفلاین** و **فارسی‌زبان** کار می‌کند. بدون نیاز به اینترنت، مدارهای ترکیبی و ترتیبی را طراحی، شبیه‌سازی و تحلیل کنید.

- 🧩 **۸۰+ قطعه** در ۱۲ گروه (گیت‌ها، قطعات حسابی، مالتی‌پلکسرها، دیکودرها، قفل‌ها، فلیپ‌فلپ‌ها، ثبات‌ها و شمارنده‌ها)
- ⚡ **شبیه‌سازی ۴ مرحله‌ای** با پشتیبانی از حالت ترتیبی (فلیپ‌فلپ، ثبات، شمارنده)
- 📊 **جدول حقیقت** خودکار با خروجی CSV
- 🧮 **ابزارهای بولی** — تجزیه، ساده‌سازی و تبدیل عبارت به مدار
- 🎓 **مسیر یادگیری** با درس، چالش و تمرین
- 💾 **ذخیره‌سازی محلی** با SQLite و پشتیبان‌گیری JSON

---

## ✨ ویژگی‌ها

### ویرایشگر مدار
- کشیدن و رها کردن قطعات روی بوم
- اتصال پایه به پایه با پیش‌نمایش سیم
- زوم، پن و شبکهٔ ۲۴ واحدی
- لغو/تکرار (Undo/Redo) نامحدود
- ذخیرهٔ خودکار و بازیابی حالت
- حالت انتخاب گروهی برای حذف چندتایی

### شبیه‌سازی
- سیگنال‌های ۴ حالته: `0`، `1`، `?` (نامشخص)، `Z` (امپدانس بالا)
- تشخیص مدار ترکیبی vs ترتیبی
- گزارش خطاهای اتصال و قطعات نامعتبر
- بازخورد لمسی و بصری

### پروژه‌ها
- ایجاد، ویرایش، تکثیر، تغییر نام و حذف
- وارد/خارج کردن JSON با اعتبارسنجی دقیق
- پشتیبان‌گیری کامل (پروژه‌ها + پیشرفت + تنظیمات)
- جست‌وجو و مرتب‌سازی

### یادگیری
- درس‌های تعاملی از سیگنال دیجیتال تا حافظه و ترتیب
- چالش‌های ساخت مدار با بازخورد
- پیشرفت و XP
- مرجع گیت‌ها

### تنظیمات
- تم روشن/تاریک/سیستم
- پالت رنگ قابل تنظیم
- اندازهٔ فونت
- تنظیمات شبیه‌سازی (سقف تکرار، تأخیر)
- دربارهٔ برنامه

---

## 🧩 کتابخانهٔ قطعات

| گروه | قطعات |
|---|---|
| ورودی و خروجی | ورودی، خروجی، منبع کلاک |
| گیت‌های منطقی | AND، OR، NOT، NAND، NOR، XOR، XNOR، بافر و بافر سه‌حالته |
| گیت‌های چندورودی | AND، OR، NAND، NOR، XOR و XNOR با **۲ تا ۸ ورودی** |
| گیت‌های مرکب | AOI21، AOI22، OAI21، OAI22 |
| قطعات حسابی | نیم‌جمع‌کننده، جمع‌کنندهٔ کامل، نیم‌تفریق‌کننده، تفریق‌کنندهٔ کامل و مقایسه‌گر ۲ بیتی |
| انتخابگرها | MUX 2:1 و 4:1؛ DEMUX 1:2 و 1:4 |
| کدگذار/کدگشا | دیکودر 2→4 و 3→8؛ انکودر 4→2 و 8→3؛ انکودر اولویت‌دار |
| قفل‌ها و فلیپ‌فلپ‌ها | قفل SR، قفل SR دروازه‌دار، قفل D و فلیپ‌فلپ‌های D، T و JK |
| ثبات‌ها و شمارنده‌ها | ثبات ۴ بیتی، ثبات انتقال ۴ بیتی، شمارندهٔ ۴ بیتی و شمارندهٔ بالا/پایین |

تعریف قطعات و پایه‌های آن‌ها در [ComponentSpec](lib/features/editor/domain/component_spec.dart) متمرکز است.

---

## 📸 تصاویر

<table align="center">
  <tr>
    <td align="center"><img src="preview.png" alt="Main" width="260" style="border-radius:10px;border:1px solid #ddd;" /></td>
    <td align="center"><img src="preview_home.png" alt="Home" width="260" style="border-radius:10px;border:1px solid #ddd;" /></td>
  </tr>
  <tr>
    <td align="center"><sub>محیط اصلی</sub></td>
    <td align="center"><sub>داشبورد</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="preview_projects.png" alt="Projects" width="260" style="border-radius:10px;border:1px solid #ddd;" /></td>
    <td align="center"><img src="preview_settings.png" alt="Settings" width="260" style="border-radius:10px;border:1px solid #ddd;" /></td>
  </tr>
  <tr>
    <td align="center"><sub>پروژه‌ها</sub></td>
    <td align="center"><sub>تنظیمات</sub></td>
  </tr>
</table>

## 🚀 شروع سریع

### پیش‌نیازها
- [Flutter](https://flutter.dev) 3.29.3
- [Dart](https://dart.dev) 3.7.2
- Android SDK / Java 17 (برای بیلد اندروید)

### اجرا
```bash
git clone https://github.com/ScrollBots/Logic-Lab.git
cd Logic-Lab
flutter pub get
flutter run
```

### بررسی و بیلد
```bash
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub
```

---

## 🏗️ معماری

پروژه به صورت **feature-first** سازمان‌دهی شده:

```
lib/
├── app/          # ریشهٔ برنامه، مسیریابی و پوستهٔ ناوبری
├── core/         # داده، زبان، پوسته، سرویس‌ها و ویجت‌های مشترک
└── features/
    ├── editor/        # domain / application / presentation
    ├── projects/      # مدل، قالب فایل، مخزن و فهرست پروژه‌ها
    ├── truth_table/   # تولید و نمایش جدول حقیقت
    ├── analysis/      # تحلیل و مقایسهٔ مدار
    ├── boolean_tools/ # تجزیه، ساده‌سازی و تبدیل عبارت
    ├── learn/         # درس‌ها، چالش‌ها و پیشرفت
    ├── lab/           # گیت‌های تعاملی و مدارهای آماده
    ├── home/          # داشبورد
    ├── settings/      # ظاهر، رفتار و مدیریت داده
    └── splash/        # صفحهٔ آغازین
```

```
Presentation → Application → Domain
                    ↓
               Repository
```

---

## 🧪 کیفیت و انتشار

| گردش‌کار | زمان اجرا | نتیجه |
|---|---|---|
| [CI](.github/workflows/ci.yml) | push و pull request به `main` | اعتبارسنجی تنظیمات، تست متون انتشار، فرمت Dart، تحلیل و اجرای همهٔ آزمون‌ها |
| [Release](.github/workflows/release.yml) | تگ `v*` یا اجرای دستی | دروازهٔ کیفیت مستقل، سپس ساخت، بررسی و انتشار سه خروجی اصلی |
| [Web preview](.github/workflows/web-preview.yml) | اجرای دستی یا فعال‌سازی | پیش‌نمایش اختیاری، خارج از مسیر انتشار |

---

## 📄 مجوز

کد اصلی و مستندات این پروژه تحت **[MIT License](LICENSE)** ارائه می‌شوند.

فونت‌ها مجوزهای مستقل خود را دارند:

| قلم | کاربرد | مجوز |
|---|---|---|
| [Vazirmatn](https://github.com/rastikerdar/vazirmatn) | رابط فارسی | [SIL OFL 1.1](assets/fonts/OFL.txt) |
| JetBrains Mono | بیت‌ها، شناسه‌ها و عبارت‌ها | [SIL OFL 1.1](assets/fonts/JetBrainsMono-OFL.txt) |

---

<p align="center">
  ساخته شده با ❤️ و Flutter
</p>
