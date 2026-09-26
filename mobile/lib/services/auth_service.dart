import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_sync_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firebase Web Client ID (Google Auth için zorunlu)
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: "23507411940-2g0ek9pinfl8bpdg0bssr454k5blk8fh.apps.googleusercontent.com",
    scopes: ['email', 'profile'],
  );

  // Mevcut giriş yapmış kullanıcı
  static User? get currentUser => _auth.currentUser;

  // Kullanıcı oturum durumu dinleyicisi
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile Giriş Yap Fonksiyonu
  static Future<User?> signInWithGoogle() async {
    try {
      // 1. Önceki oturum kalıntısı varsa temizle
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // 2. Google Hesap Seçim Ekranını Başlat
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı pencereyi kapattı veya seçim yapmadı
        if (kDebugMode) print("ℹ️ Google hesabı seçilmeden kapatıldı.");
        return null;
      }

      // 3. Kimlik doğrulama detaylarını al (Access Token & ID Token)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception("Google kimlik belirteci (token) alınamadı. SHA-1 parmak izini kontrol edin.");
      }

      // 4. Firebase Kimlik Kartı (Credential) oluştur
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Firebase'e giriş yap
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseSyncService.markGoogleLoggedIn(true);
        await FirebaseSyncService.restoreUserDataFromCloud();
      }

      if (kDebugMode) {
        print("✅ Google Girişi Başarılı: ${user?.displayName} (${user?.email})");
      }

      return user;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Google Giriş Hatası: $e");
      }
      rethrow;
    }
  }

  // Çıkış Yap
  static Future<void> signOut() async {
    try {
      await FirebaseSyncService.clearLocalUserData();
      await _googleSignIn.signOut();
      await _auth.signOut();
      if (kDebugMode) {
        print("🚪 Kullanıcı çıkış yaptı ve tüm yerel VIP/oturum verileri temizlendi.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Çıkış hatası: $e");
      }
    }
  }
}
