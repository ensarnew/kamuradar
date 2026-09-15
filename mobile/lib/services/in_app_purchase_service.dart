import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'firebase_sync_service.dart';

class InAppPurchaseService {
  static final InAppPurchaseService instance = InAppPurchaseService._internal();
  InAppPurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Google Play Console SKU Tanımları
  static const String monthlyVipId = 'kamuradar_monthly_vip';
  static const String yearlyVipId = 'kamuradar_yearly_vip';
  static const Set<String> productIds = {monthlyVipId, yearlyVipId};

  bool _isStoreAvailable = false;
  List<ProductDetails> _products = [];
  bool get isStoreAvailable => _isStoreAvailable;
  List<ProductDetails> get products => _products;

  // Satın alım başarılı olduğunda çağrılacak dinleyici
  Function(String planKey)? onPurchaseCompleted;
  Function(String error)? onPurchaseFailed;

  /// Servisi başlatır ve Google Play faturalandırma akışını dinler
  Future<void> initialize() async {
    try {
      _isStoreAvailable = await _iap.isAvailable();
      if (kDebugMode) {
        print("🛒 Google Play Billing Kullanılabilir mi: $_isStoreAvailable");
      }

      // Satın alma akışını dinle
      _subscription?.cancel();
      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (error) {
          if (kDebugMode) print("❌ Play Billing Akış Hatası: $error");
        },
      );

      // Ürün bilgilerini mağazadan sorgula
      if (_isStoreAvailable) {
        await loadProducts();
      }
    } catch (e) {
      if (kDebugMode) print("❌ InAppPurchase init hatası: $e");
    }
  }

  /// Google Play'den kayıtlı ürün detaylarını çeker
  Future<void> loadProducts() async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      if (response.error != null) {
        if (kDebugMode) {
          print("❌ Ürün sorgulama hatası: ${response.error!.message}");
        }
        return;
      }
      _products = response.productDetails;
      if (kDebugMode) {
        print("🛒 Play Store'dan ${_products.length} ürün başarıyla yüklendi.");
      }
    } catch (e) {
      if (kDebugMode) print("❌ Ürün yükleme exception: $e");
    }
  }

  /// Satın alma akışını başlatır (Google Play Resmi Satın Alma Penceresi)
  Future<bool> buyProduct(String productId) async {
    try {
      // 1. Mağaza hazır mı kontrolü
      if (!_isStoreAvailable) {
        onPurchaseFailed?.call("Google Play Store bağlantısı kurulamadı. Lütfen Play Store hesabınızı ve internetinizi kontrol edin.");
        return false;
      }

      // 2. Ürünü bul
      ProductDetails? product;
      for (var p in _products) {
        if (p.id == productId) {
          product = p;
          break;
        }
      }

      // Ürün henüz Google Play Console'da onaylanmamış veya yayınlanmamışsa
      if (product == null) {
        // Fallback: Ürün detay nesnesi oluşturup dene
        final response = await _iap.queryProductDetails({productId});
        if (response.productDetails.isNotEmpty) {
          product = response.productDetails.first;
        }
      }

      if (product == null) {
        onPurchaseFailed?.call("Ürün ($productId) Google Play Store'da henüz aktif değil veya yayınlanmamış.");
        return false;
      }

      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onPurchaseFailed?.call("Satın alma başlatılamadı: $e");
      return false;
    }
  }

  /// Geçmiş Satın Alımları Geri Yükle
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      onPurchaseFailed?.call("Satın alımlar geri yüklenemedi: $e");
    }
  }

  /// Satın alma güncellemelerini işler
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Ödeme bekleniyor (örneğin bakiye onayı)
        if (kDebugMode) print("⏳ Ödeme onay bekliyor: ${purchaseDetails.productID}");
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Hata veya kullanıcı iptal etti
        final errorMessage = purchaseDetails.error?.message ?? "Ödeme işlemi iptal edildi veya başarısız oldu.";
        if (kDebugMode) print("❌ Ödeme hatası: $errorMessage");
        onPurchaseFailed?.call(errorMessage);
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // BAŞARILI SATIN ALIM VEYA RESTORE
        final planKey = purchaseDetails.productID == yearlyVipId ? "yearly_vip" : "monthly_vip";

        // VIP durumunu hem cihaza hem Firestore'a kaydet
        await FirebaseSyncService.setVipStatus(true, plan: planKey);

        if (kDebugMode) {
          print("👑 Satın alma başarıyla onaylandı: ${purchaseDetails.productID} ($planKey)");
        }

        // Satın alımı tamamla
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }

        // Arayüze haber ver
        onPurchaseCompleted?.call(planKey);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
