import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  Locale _locale = const Locale('ar');

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

  // تحميل الإعدادات عند فتح التطبيق
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    String lang = prefs.getString('languageCode') ?? 'ar';
    _locale = Locale(lang);
    notifyListeners();
  }

  // تحديث بيانات المستخدم في فيرستور (الدالة مكانها هنا)
  Future<void> updateUserData(String uid, String newName) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': newName,
      });
      notifyListeners(); // هنا الجرس بيشتغل صح
    } catch (e) {
      debugPrint("Error updating user: $e");
    }
  }
}