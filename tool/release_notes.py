import argparse
import re
from pathlib import Path


VERSION_PATTERN = r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?"
VERSION_DIGITS = str.maketrans("۰۱۲۳۴۵۶۷۸۹٫", "0123456789.")


def generate_notes(readme, version, build):
    if not re.fullmatch(VERSION_PATTERN, version) or not re.fullmatch(r"[0-9]+", build):
        raise ValueError("Expected a semantic version and a numeric build number.")

    section = re.search(r"^## .*یادداشت‌های انتشار\s*$", readme, re.MULTILINE)
    if section is None:
        raise ValueError("README.md has no release-notes section.")
    content = readme[section.end():]
    end = re.search(r"^## ", content, re.MULTILINE)
    if end:
        content = content[:end.start()]

    notes = ""
    headings = list(re.finditer(r"^### نسخهٔ (.+)$", content, re.MULTILINE))
    for index, heading in enumerate(headings):
        if heading.group(1).strip().translate(VERSION_DIGITS) != version:
            continue
        stop = headings[index + 1].start() if index + 1 < len(headings) else len(content)
        notes = content[heading.end():stop].strip()
        break
    if not re.search(r"^[*-] \S", notes, re.MULTILINE):
        raise ValueError(f"Add meaningful release notes for {version} to README.md before publishing.")

    return (
        f"## Logic Lab {version}\n\n"
        f"نسخهٔ اندروید آزمایشگاه منطق — شمارهٔ بیلد `{build}`.\n\n"
        f"### تغییرات این نسخه\n\n{notes}\n\n"
        "### دریافت و نصب\n\n"
        "| فایل | کاربرد |\n|---|---|\n"
        "| `app-arm64-v8a-release.apk` | نصب مستقیم روی دستگاه‌های ARM 64-bit |\n"
        "| `app-armeabi-v7a-release.apk` | نصب مستقیم روی دستگاه‌های ARM 32-bit |\n"
        "| `app-x86_64-release.apk` | نصب روی دستگاه‌ها یا شبیه‌سازهای x86_64 |\n"
        "| `app-release.aab` | بستهٔ توزیع اندروید؛ برای نصب مستقیم از APK استفاده کنید |\n\n"
        "### کنترل کیفیت\n\n"
        "این فایل‌ها پس از موفقیت اعتبارسنجی گردش‌کار، بررسی فرمت، تحلیل ایستا و "
        "همهٔ تست‌های واحد و ویجت ساخته می‌شوند. امضا، شناسه، برچسب و نسخهٔ APKها "
        "و امضای AAB پیش از انتشار بررسی می‌شوند.\n\n"
        "موفقیت بررسی‌های خودکار به معنی تأیید لمس، عملکرد یا لرزش روی گوشی واقعی نیست.\n"
    )


def main():
    parser = argparse.ArgumentParser(description="Prepare version-specific Persian Android release notes.")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--readme", default="README.md")
    parser.add_argument("--output", required=True)
    arguments = parser.parse_args()
    try:
        notes = generate_notes(
            Path(arguments.readme).read_text(encoding="utf-8"), arguments.version, arguments.build
        )
    except ValueError as error:
        raise SystemExit(f"Release notes are not ready: {error}") from error
    Path(arguments.output).write_text(notes, encoding="utf-8")
    print(f"Prepared Persian release notes for Logic Lab {arguments.version} (build {arguments.build}).")


if __name__ == "__main__":
    main()
