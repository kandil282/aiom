import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  Locale _locale = const Locale('ar'); // اللغة الافتراضية عربي

  bool get isDarkMode => _isDarkMode;
  Locale get locale => _locale;

  SettingsProvider() {
    _loadSettings();
  }

  // تبديل الثيم
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }

  // تبديل اللغة
  void setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('languageCode', languageCode);
  }

  // تحميل الإعدادات المحفوظة
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    String lang = prefs.getString('languageCode') ?? 'ar';
    _locale = Locale(lang);
    notifyListeners();
  }
  Future<void> updateUserData(String uid, String newName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': newName,
      });
      notifyListeners(); // هذا السطر هو ما يجعل الاسم يتحدث في الهوم فوراً
    } catch (e) {
      print("Error: $e");
    }
  }



}


class AppStrings {
  static Map<String, Map<String, String>> translations = {
    'ar': {
      'app_title': 'نظام إدارة المؤسسة',
      'hr_section': 'الإدارة والـ HR',
      'hr_manage': 'إدارة الموظفين',
      'sales_section': 'المبيعات والعملاء',
      'shipping_section': 'الشحن والنقل',
      'is_courier': 'مندوب التوصيل',
      'logout': 'تسجيل الخروج',
      // أضف كل النصوص هنا...
    },
    'en': {
      'app_title': 'Enterprise ERP System',
      'hr_section': 'Management & HR',
      'hr_manage': 'Employee Management',
      'sales_section': 'Sales & Customers',
      'shipping_section': 'Shipping & Logistics',
      'is_courier': 'Courier Dashboard',
      'logout': 'Logout',
    }
  };

  static String get(String key, String lang) {
    return translations[lang]?[key] ?? key;
  }
}
