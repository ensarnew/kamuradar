import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  // Unity Cloud Dashboard Kimlikleri (kamurdar)
  static const String androidGameId = '800372910';
  static const String rewardedPlacementId = 'BP_Rewarded_Android';
  static const String interstitialPlacementId = 'BP_Interstitial_Android';

  bool _isInitialized = false;
  bool _isRewardedLoaded = false;
  bool _isLoading = false;

  bool get isRewardedLoaded => _isRewardedLoaded;
  bool get isInitialized => _isInitialized;

  /// Unity Ads SDK'sını başlatır
  Future<void> initialize({bool testMode = false}) async {
    if (kIsWeb) {
      debugPrint('[AdService] Web platformunda Unity Ads simülasyon modunda çalışır.');
      _isInitialized = true;
      _isRewardedLoaded = true;
      return;
    }

    try {
      await UnityAds.init(
        gameId: androidGameId,
        testMode: testMode,
        onComplete: () {
          debugPrint('[AdService] Unity Ads başarıyla başlatıldı (Game ID: $androidGameId)');
          _isInitialized = true;
          loadRewardedAd();
          loadInterstitialAd();
        },
        onFailed: (error, message) {
          debugPrint('[AdService] Unity Ads başlatma hatası: $error - $message');
          _isInitialized = false;
        },
      );
    } catch (e) {
      debugPrint('[AdService] Unity Ads init exception: $e');
    }
  }

  /// Geçiş reklamını arka planda yükler
  void loadInterstitialAd() {
    if (kIsWeb) return;
    UnityAds.load(
      placementId: interstitialPlacementId,
      onComplete: (placementId) => debugPrint('[AdService] Geçiş reklamı yüklendi: $placementId'),
      onFailed: (placementId, error, message) => debugPrint('[AdService] Geçiş reklamı yüklenemedi: $placementId'),
    );
  }

  /// Ödüllü videoyu arka planda hazır bekletmek için önceden yükler
  void loadRewardedAd() {
    if (kIsWeb) {
      _isRewardedLoaded = true;
      return;
    }

    if (_isLoading) return;
    _isLoading = true;

    UnityAds.load(
      placementId: rewardedPlacementId,
      onComplete: (placementId) {
        debugPrint('[AdService] Ödüllü video hazır: $placementId');
        _isRewardedLoaded = true;
        _isLoading = false;
      },
      onFailed: (placementId, error, message) {
        debugPrint('[AdService] Ödüllü video yüklenemedi: $placementId ($error: $message)');
        _isRewardedLoaded = false;
        _isLoading = false;
      },
    );
  }

  /// Ödüllü videoyu oynatır (+2 Bildirim Alma Hakkı Kazandırır)
  void showRewardedAd({
    required VoidCallback onRewardEarned,
    required ValueChanged<String> onFailure,
    VoidCallback? onStarted,
  }) {
    // Web veya test/emülatör fallback desteği
    if (kIsWeb) {
      debugPrint('[AdService] Web simülasyon ödülü verildi.');
      onRewardEarned();
      return;
    }

    if (!_isInitialized) {
      // SDK henüz hazır değilse yeniden başlatmayı dene ve kullanıcıya bilgi ver
      initialize();
      onFailure('Reklam ağı hazırlanıyor, lütfen 3 saniye sonra tekrar deneyin.');
      return;
    }

    _isRewardedLoaded = false;

    UnityAds.showVideoAd(
      placementId: rewardedPlacementId,
      onStart: (placementId) {
        debugPrint('[AdService] Reklam başladı: $placementId');
        onStarted?.call();
      },
      onClick: (placementId) {
        debugPrint('[AdService] Reklama tıklandı: $placementId');
      },
      onSkipped: (placementId) {
        debugPrint('[AdService] Reklam atlandı (Ödül verilmedi)');
        onFailure('Video sonuna kadar izlenmediği için +2 bildirim hakkı eklenemedi.');
        loadRewardedAd(); // Bir sonraki için hazırla
      },
      onComplete: (placementId) {
        debugPrint('[AdService] Reklam tamamlandı! +2 Bildirim hakkı veriliyor.');
        onRewardEarned();
        loadRewardedAd(); // Bir sonraki için hazırla
      },
      onFailed: (placementId, error, message) {
        debugPrint('[AdService] Reklam gösterim hatası: $error - $message');
        onFailure('Reklam yüklenirken bir sorun oluştu: $message');
        loadRewardedAd();
      },
    );
  }

  /// Geçiş Reklamı (İsteğe bağlı - kritik işlem sonrası)
  void showInterstitialAd({VoidCallback? onComplete}) {
    if (kIsWeb || !_isInitialized) {
      onComplete?.call();
      return;
    }

    UnityAds.showVideoAd(
      placementId: interstitialPlacementId,
      onComplete: (placementId) {
        onComplete?.call();
        UnityAds.load(placementId: interstitialPlacementId);
      },
      onFailed: (placementId, error, message) {
        onComplete?.call();
      },
      onSkipped: (placementId) {
        onComplete?.call();
      },
    );
  }
}
