import 'package:flutter/material.dart';

class Translate {
  // الدالة دي بتاخد السياق والنص العربي والنص الإنجليزي
  static String text(BuildContext context, String ar, String en) {
    // بتعرف لغة التطبيق الحالية من الـ Locale
    bool isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return isArabic ? ar : en;
  }
}