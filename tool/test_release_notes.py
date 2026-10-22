import unittest

from release_notes import generate_notes


class ReleaseNotesTest(unittest.TestCase):
    def test_extracts_only_the_requested_version(self):
        readme = """# Logic Lab
## ۱۴. یادداشت‌های انتشار
### نسخهٔ ۱٫۳٫۰
* بهبود تعامل بوم.

### نسخهٔ ۱٫۲٫۰
* تغییرات قدیمی.
## ۱۵. نقشهٔ راه
* قابلیت آینده.
"""
        notes = generate_notes(readme, "1.3.0", "4")
        self.assertIn("بهبود تعامل بوم.", notes)
        self.assertNotIn("تغییرات قدیمی.", notes)
        self.assertNotIn("قابلیت آینده.", notes)
        self.assertIn("Logic Lab 1.3.0", notes)
        self.assertIn("`4`", notes)
        self.assertIn("app-arm64-v8a-release.apk", notes)
        self.assertIn("app-release.aab", notes)
        self.assertIn("گوشی واقعی", notes)

    def test_accepts_ascii_and_prerelease_headings(self):
        readme = "## یادداشت‌های انتشار\n### نسخهٔ 1.3.0-rc.1\n* رفع یک خطا.\n"
        self.assertIn("رفع یک خطا.", generate_notes(readme, "1.3.0-rc.1", "5"))

    def test_rejects_missing_or_empty_notes(self):
        for readme in (
            "# Logic Lab",
            "## یادداشت‌های انتشار\n### نسخهٔ 1.2.0\n* نسخهٔ قبلی.\n",
            "## یادداشت‌های انتشار\n### نسخهٔ 1.3.0\n",
            "## یادداشت‌های انتشار\n### نسخهٔ 1.3.0\nمتن بدون تغییر مشخص.\n",
        ):
            with self.subTest(readme=readme), self.assertRaises(ValueError):
                generate_notes(readme, "1.3.0", "4")

    def test_does_not_take_notes_from_outside_the_release_section(self):
        readme = """## معرفی
### نسخهٔ 1.3.0
* این متن یادداشت انتشار نیست.
## یادداشت‌های انتشار
### نسخهٔ 1.2.0
* نسخهٔ قبلی.
## نقشهٔ راه
### نسخهٔ 1.3.0
* برنامهٔ آینده.
"""
        with self.assertRaises(ValueError):
            generate_notes(readme, "1.3.0", "4")

    def test_rejects_invalid_version_and_build(self):
        for version, build in (("v1.3.0", "4"), ("1.3", "4"), ("1.3.0", "x")):
            with self.subTest(version=version, build=build), self.assertRaises(ValueError):
                generate_notes("", version, build)


if __name__ == "__main__":
    unittest.main()
