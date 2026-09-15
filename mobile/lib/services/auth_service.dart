import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_sync_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mevcut giriş yapmış kullanıcı
  static User? get currentUser => _auth.currentUser;

  // Kullanıcı oturum durumu dinleyicisi
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile Giriş Yap Fonksiyonu
  static Future<User?> signInWithGoogle() async {
    try {
      // 1. Google Hesap Seçim Ekranını Başlat
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Kullanıcı seçmeden kapattı
        return null;
      }

      // 2. Kimlik doğrulama detaylarını al (Access Token & ID Token)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Firebase Kimlik Kartı (Credential) oluştur
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase'e giriş yap
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
      await FirebaseSyncService.markGoogleLoggedIn(false);
      await FirebaseSyncService.setGuestMode(false);
      await _googleSignIn.signOut();
      await _auth.signOut();
      if (kDebugMode) {
        print("🚪 Kullanıcı çıkış yaptı.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Çıkış hatası: $e");
      }
    }
  }
}
