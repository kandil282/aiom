import 'package:aiom/configer/settings_provider.dart';
import 'package:aiom/views/homePage.dart';
import 'package:aiom/views/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: await DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('ar', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      // 1. تحديد اللغات المدعومة
      supportedLocales: const [
        Locale('ar'), 
        Locale('en')
      ],

      // 2. إضافة الـ Delegates (هذا الجزء هو سر تشغيل الزرار والاتجاهات)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // 3. ربط اللغة بالـ Provider
      locale: settingsProvider.locale,

      // 4. ربط الـ Theme بالـ Provider
      themeMode: settingsProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // ثيم الوضع الفاتح
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blueGrey,
        fontFamily: 'Cairo',
        // تحسين ألوان الـ AppBar في الوضع الفاتح
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff692960),
          centerTitle: true,
        ),
      ),

      // ثيم الوضع الداكن
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff0f172a),
        cardColor: const Color(0xff1e293b), // لون الكروت في الدارك مود
        primarySwatch: Colors.amber,
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff1e293b),
          centerTitle: true,
        ),
      ),

      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (userSnap.hasData && userSnap.data!.exists) {
                var data = userSnap.data!.data() as Map<String, dynamic>;
                
                if (data['hasAppAccess'] == false) {
                  return const LoginPage();
                }

                return HomePage(
                  userName: data['username'] ?? data['name'] ?? "مستخدم",
                  email: data['email'] ?? snapshot.data!.email ?? "",
                  roles: List<dynamic>.from(data['roles'] ?? data['rolls'] ?? []),
                );
              }
              
              return const LoginPage();
            },
          );
        }
        
        return const LoginPage();
      },
    );
  }
}
