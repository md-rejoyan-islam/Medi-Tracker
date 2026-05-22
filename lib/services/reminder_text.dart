import '../data/settings_store.dart';

/// Localized strings for OS notification text (title + body).
///
/// Kept as a tiny standalone helper rather than full Flutter i18n because
/// the only thing currently varying by language is the reminder text the
/// user sees on the lock screen. UI labels remain English until a proper
/// `flutter_localizations` ARB setup lands (separate effort).
///
/// Medication names stay verbatim — most users name their meds in the
/// language they're prescribed in (often the drug brand name), so we
/// preserve that exactly and wrap it in a localized sentence.
class ReminderText {
  ReminderText._();

  /// Notification title shown at the dose time.
  static String title(String medName, ReminderLanguage lang) {
    switch (lang) {
      case ReminderLanguage.english:
        return 'Time for $medName';
      case ReminderLanguage.bengali:
        return '$medName খাওয়ার সময় হয়েছে';
      case ReminderLanguage.bilingual:
        return '$medName · খাওয়ার সময়';
    }
  }

  /// Notification body. Dosage (if present) prepends a localized
  /// "tap when taken" hint.
  static String body(String dosage, ReminderLanguage lang) {
    final hint = switch (lang) {
      ReminderLanguage.english => 'Tap when taken',
      ReminderLanguage.bengali => 'নিলে এখানে ট্যাপ করুন',
      ReminderLanguage.bilingual => 'নিলে ট্যাপ করুন · Tap when taken',
    };
    return dosage.isEmpty ? hint : '$dosage  ·  $hint';
  }

  /// Title for the manual "Send test notification" diagnostic.
  static String testTitle(ReminderLanguage lang) {
    return switch (lang) {
      ReminderLanguage.english => 'MediTracker test reminder',
      ReminderLanguage.bengali => 'মেডিট্র্যাকার পরীক্ষামূলক রিমাইন্ডার',
      ReminderLanguage.bilingual =>
        'MediTracker · পরীক্ষামূলক রিমাইন্ডার',
    };
  }

  static String testBody(ReminderLanguage lang) {
    return switch (lang) {
      ReminderLanguage.english =>
        'If you see this with sound, notifications are wired correctly.',
      ReminderLanguage.bengali =>
        'এই বার্তা শব্দসহ দেখা গেলে নোটিফিকেশন সঠিকভাবে কাজ করছে।',
      ReminderLanguage.bilingual =>
        'Sound + this message means notifications work · '
        'শব্দসহ দেখালে কাজ করছে',
    };
  }
}
