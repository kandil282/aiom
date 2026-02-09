import 'package:aiom/configer/settings_provider.dart'; // تأكد أن المسار صحيح
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}
class Translate {
  static String text(BuildContext context, String ar, String en) {
    // بيقرأ اللغة من الـ Provider اللي عندك
    bool isAr = Provider.of<SettingsProvider>(context, listen: false).locale.languageCode == 'ar';
    return isAr ? ar : en;
  }
}

class _SettingsPageState extends State<SettingsPage> {
  final _nameController = TextEditingController();
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    // نربط الشاشة بالبروفايدر
    final settings = Provider.of<SettingsProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final isAr = settings.locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? "الإعدادات والملف الشخصي" : "Settings & Profile"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // قسم الملف الشخصي
            _buildProfileHeader(user, settings, isAr),
            const SizedBox(height: 30),

            // قسم إعدادات التطبيق
            _buildSectionTitle(isAr ? "إعدادات التطبيق" : "App Settings"),
            _buildSettingCard(
              title: isAr ? "الوضع الليلي" : "Dark Mode",
              subtitle: isAr ? "تبديل المظهر" : "Switch Appearance",
              icon: Icons.brightness_6,
              trailing: Switch(
                value: settings.isDarkMode,
                onChanged: (val) => settings.toggleTheme(),
              ),
            ),
            _buildSettingCard(
              title: isAr ? "اللغة" : "Language",
              subtitle: isAr ? "العربية / English" : "Arabic / English",
              icon: Icons.language,
              trailing: TextButton(
                onPressed: () => settings.setLocale(isAr ? 'en' : 'ar'),
                child: Text(isAr ? "English" : "العربية"),
              ),
            ),

            const SizedBox(height: 20),

            // قسم الأمان
            _buildSectionTitle(isAr ? "الأمان" : "Security"),
            _buildSettingCard(
              title: isAr ? "تغيير كلمة المرور" : "Change Password",
              subtitle: isAr ? "إرسال رابط التعيين" : "Send reset link",
              icon: Icons.lock_reset,
              onTap: () => _resetPassword(user?.email, isAr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User? user, SettingsProvider settings, bool isAr) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        var userData = snapshot.data!.data() as Map<String, dynamic>;
        
        // تحديث النص فقط في حالة عدم التعديل
        if (!_isEditing) _nameController.text = userData['username'] ?? "";

        return Column(
          children: [
            const CircleAvatar(radius: 50, backgroundColor: Colors.amber, child: Icon(Icons.person, size: 50, color: Colors.white)),
            const SizedBox(height: 15),
            _isEditing
                ? TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: isAr ? "الاسم الجديد" : "New Name",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () {
                          // هنا بننادي الدالة من البروفايدر صح
                          settings.updateUserData(user!.uid, _nameController.text);
                          setState(() => _isEditing = false);
                        },
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(userData['username'] ?? "", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => setState(() => _isEditing = true)),
                    ],
                  ),
            Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
      ),
    );
  }

  Widget _buildSettingCard({required String title, required String subtitle, required IconData icon, Widget? trailing, VoidCallback? onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }

  void _resetPassword(String? email, bool isAr) async {
    if (email != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? "تم إرسال الرابط" : "Reset link sent"))
      );
    }
  }
}