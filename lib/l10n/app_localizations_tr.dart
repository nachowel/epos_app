// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'EPOS';

  @override
  String get loginTitle => 'PIN Giriş';

  @override
  String get pinLabel => 'PIN';

  @override
  String get loginButton => 'Giriş Yap';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get errorGeneric => 'İşlem başarısız.';

  @override
  String get enterPin => 'PIN girin.';

  @override
  String get loginFailed => 'Giriş başarısız.';

  @override
  String get invalidPinOrInactiveUser => 'Geçersiz PIN veya pasif kullanıcı.';

  @override
  String get authLocked => 'Çok fazla hatalı deneme. 30 saniye bekleyin.';

  @override
  String get navPos => 'POS';

  @override
  String get navOrders => 'Açık Siparişler';

  @override
  String get navReports => 'Raporlar';

  @override
  String get navAdmin => 'Admin';

  @override
  String get navShifts => 'Vardiya Yönetimi';

  @override
  String get navSettings => 'Ayarlar';

  @override
  String get navLogout => 'Çıkış';

  @override
  String get shiftActive => 'Aktif Vardiya';

  @override
  String get shiftInactive => 'Vardiya Yok';

  @override
  String get shiftOpen => 'Vardiya Açık';

  @override
  String get shiftClosed => 'Vardiya Kapalı';

  @override
  String get shiftLocked => 'Vardiya Kilitli';

  @override
  String get recentShifts => 'Son Vardiyalar';

  @override
  String get noShiftHistory => 'Henüz vardiya geçmişi yok';

  @override
  String get adminOnlyShiftMessage =>
      'Gerçek gün sonu kapanışı yalnızca yönetici tarafından tamamlanabilir.';

  @override
  String get closeShiftConfirmation =>
      'Vardiya final Z raporu ile kapatılacak.';

  @override
  String get openOrdersBlockTitle => 'Kapanış bloklu — aktif siparişler var';

  @override
  String get goToOpenOrders => 'Açık Siparişlere Git';

  @override
  String get shiftOpened => 'Vardiya açıldı.';

  @override
  String get shiftClosedMessage =>
      'Vardiya kapalı — devam etmek için vardiya açın';

  @override
  String get lastClosedShift => 'Son Kapanan Vardiya';

  @override
  String get openedBy => 'Açan';

  @override
  String get closedBy => 'Kapatan';

  @override
  String get cashierPreviewedBy => 'Kasiyer Önizleme Kullanıcısı';

  @override
  String get cashierPreviewedAt => 'Kasiyer Önizleme Saati';

  @override
  String get cashierPreviewPending => 'Kasiyer önizlemesi henüz alınmadı.';

  @override
  String get noRecentActivity => 'Henüz son aktivite yok.';

  @override
  String get cashAwarenessTitle => 'Kasa Farkındalığı';

  @override
  String get goToPosNewOrder => 'POS / Yeni Sipariş';

  @override
  String get maskedCashCollected => 'Maskeli nakit tahsilatı';

  @override
  String get manualCashMovements => 'Manuel kasa hareketleri';

  @override
  String get netTillMovement => 'Net kasa hareketi';

  @override
  String get openedAt => 'Açılış';

  @override
  String get closedAt => 'Kapanış';

  @override
  String get paidOrders => 'ÖDENMİŞ Siparişler';

  @override
  String get cancelledOrders => 'İPTAL Siparişler';

  @override
  String get allCategories => 'Tümü';

  @override
  String get noCategories => 'Kategori bulunamadı';

  @override
  String get noProductsInCategory => 'Bu kategoride ürün yok';

  @override
  String get cart => 'Sepet';

  @override
  String get checkout => 'Ödeme';

  @override
  String get emptyCart => 'Sepet boş — ürün ekleyin';

  @override
  String get subtotal => 'Ara Toplam';

  @override
  String get modifierTotal => 'Modifier Toplamı';

  @override
  String get total => 'Toplam';

  @override
  String get orderNow => 'Sipariş Ver';

  @override
  String get payNow => 'Şimdi Öde';

  @override
  String get payAction => 'Öde';

  @override
  String get saveAsOpenOrder => 'Açık Sipariş Olarak Kaydet';

  @override
  String get clear => 'Temizle';

  @override
  String get modifierDialogTitle => 'Modifier Seç';

  @override
  String get includedModifiers => 'Dahil';

  @override
  String get extraModifiers => 'Ekstra';

  @override
  String get addItem => 'Sepete Ekle';

  @override
  String get removeItem => 'Öğeyi Kaldır';

  @override
  String get cancel => 'İptal';

  @override
  String get confirm => 'Onayla';

  @override
  String get close => 'Kapat';

  @override
  String get submit => 'Gönder';

  @override
  String get paymentTitle => 'Ödeme';

  @override
  String get cash => 'Nakit';

  @override
  String get card => 'Kart';

  @override
  String get receivedAmount => 'Alınan Tutar';

  @override
  String get change => 'Para Üstü';

  @override
  String get openOrdersTitle => 'Açık Siparişler';

  @override
  String get noOpenOrders => 'Açık sipariş yok';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get orderDetails => 'Sipariş Detayı';

  @override
  String get kitchenPrint => 'Mutfak Yazdır';

  @override
  String get receiptPrint => 'Fiş Yazdır';

  @override
  String get selectOpenOrderFirst => 'Önce bir açık sipariş seçin.';

  @override
  String get orderCreated => 'Sipariş oluşturuldu.';

  @override
  String get orderSent => 'Sipariş gönderildi.';

  @override
  String get orderCancelled => 'Sipariş iptal edildi.';

  @override
  String get paymentCompleted => 'Ödeme tamamlandı.';

  @override
  String get refundAction => 'İade';

  @override
  String get refundCompleted => 'İade tamamlandı.';

  @override
  String get refundDialogTitle => 'Ödemeyi İade Et';

  @override
  String get refundReasonLabel => 'İade nedeni';

  @override
  String get refundReasonHint => 'İade nedenini girin';

  @override
  String get refundReasonRequired => 'İade nedeni zorunludur.';

  @override
  String get refundAdminOnly =>
      'Yalnızca yöneticiler ödenmiş siparişleri iade edebilir veya ters çevirebilir.';

  @override
  String get refundBlockedNotPaid => 'Ödenmemiş sipariş için iade yapılamaz.';

  @override
  String get refundBlockedPaymentMissing =>
      'İade yapılamaz — ödeme kaydı bulunamadı.';

  @override
  String get refundBlockedCancelled =>
      'İptal edilmiş sipariş için iade yapılamaz.';

  @override
  String get refundAlreadyProcessed => 'Bu ödeme için iade zaten kaydedildi.';

  @override
  String get refundStatusCompleted => 'İade tamamlandı';

  @override
  String get refundedAt => 'İade zamanı';

  @override
  String get paymentFailedOrderOpen => 'Ödeme başarısız. Sipariş tamamlanmadı.';

  @override
  String get printFailed => 'Yazdırma başarısız — yeniden deneme gerekli.';

  @override
  String get printRetryRecommended =>
      'Yazdırma başarısız — sipariş ekranından yeniden deneyin.';

  @override
  String get kitchenPrintSent => 'Mutfak fişi gönderildi.';

  @override
  String get receiptPrintSent => 'Fiş yazdırıldı.';

  @override
  String get kitchenPrintPending => 'Mutfak çıktısı bekliyor.';

  @override
  String get receiptPrintPending => 'Fiş çıktısı bekliyor.';

  @override
  String get kitchenPrintInProgress => 'Mutfak çıktısı işleniyor.';

  @override
  String get receiptPrintInProgress => 'Fiş çıktısı işleniyor.';

  @override
  String get kitchenPrintRetryRequired =>
      'Mutfak çıktısı başarısız. Bu siparişten yeniden deneyin.';

  @override
  String get receiptPrintRetryRequired =>
      'Fiş çıktısı başarısız. Bu siparişten yeniden deneyin.';

  @override
  String get cancelFailed => 'İptal başarısız.';

  @override
  String get shiftNotActiveError =>
      'Aktif vardiya yok. Bir sonraki başarılı giriş yeni vardiya başlatır.';

  @override
  String get paymentUnavailable => 'Ödeme bloklu — vardiya açık olmalı.';

  @override
  String get paymentAlreadyCompleted =>
      'Bu sipariş için ödeme zaten tamamlandı.';

  @override
  String get paymentCancelledOrderBlocked =>
      'İptal edilmiş siparişler ödenemez.';

  @override
  String get paymentNotSentBlocked =>
      'Yalnızca gönderilmiş siparişler ödenebilir.';

  @override
  String get salesLockedMessage =>
      'Satış kilitli — gün sonu kapanışını yönetici tamamlamalı';

  @override
  String get cartLockedMessage => 'Sepet kilitli — vardiya işlemi gerekli';

  @override
  String get modifierLoadFailed => 'Modifier yüklenemedi.';

  @override
  String get modifierNotFound => 'Modifier bulunamadı.';

  @override
  String get confirmCancellation => 'Bu sipariş iptal edilsin mi?';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get table => 'Masa';

  @override
  String get time => 'Saat';

  @override
  String get itemCount => 'Kalem';

  @override
  String get statusOpen => 'AÇIK';

  @override
  String get statusClosed => 'KAPALI';

  @override
  String get statusLocked => 'KİLİTLİ';

  @override
  String get statusDraft => 'TASLAK';

  @override
  String get statusSent => 'GÖNDERİLDİ';

  @override
  String get statusPaid => 'ÖDENDİ';

  @override
  String get statusCancelled => 'İPTAL';

  @override
  String get orderStatusLabel => 'Durum';

  @override
  String get reports => 'Raporlar';

  @override
  String get zReport => 'Z Raporu';

  @override
  String get salesSummary => 'Satış Özeti';

  @override
  String get categoryBreakdown => 'Kategori Dağılımı';

  @override
  String get businessName => 'İşletme Adı';

  @override
  String get businessAddress => 'İşletme Adresi';

  @override
  String get reportDate => 'Rapor Tarihi';

  @override
  String get reportTime => 'Rapor Saati';

  @override
  String get shiftNumber => 'Vardiya Numarası';

  @override
  String get operatorLabel => 'Operatör';

  @override
  String get totalAmount => 'Toplam Tutar';

  @override
  String get confirmZReportAction => 'Z Raporunu Onayla';

  @override
  String get confirmFinalCloseAction => 'Final Kapanışı Onayla';

  @override
  String get endOfDay => 'Gün Sonu';

  @override
  String get cashTotal => 'Nakit Toplamı';

  @override
  String get cardTotal => 'Kart Toplamı';

  @override
  String get paymentBreakdown => 'Ödeme Dağılımı';

  @override
  String get noReportData => 'Rapor verisi bulunamadı.';

  @override
  String get selectShift => 'Vardiya Seç';

  @override
  String get totalOrders => 'Toplam Sipariş';

  @override
  String get activeShiftMissing => 'Aktif vardiya yok';

  @override
  String get reportForShift => 'Vardiya Raporu';

  @override
  String get reportForLatestShift => 'Son Vardiya Raporu';

  @override
  String get accessDenied => 'Yetki reddedildi.';

  @override
  String get notFound => 'Kayıt bulunamadı.';

  @override
  String get unknownUser => 'Bilinmeyen Kullanıcı';

  @override
  String get maskedZReportAction => 'Z Raporu';

  @override
  String get finalZReportAction => 'Final Z Raporu Al ve Vardiyayı Kapat';

  @override
  String get print => 'Yazdır';

  @override
  String get printZReportAction => 'Z Raporunu Yazdır';

  @override
  String get printUnavailable => 'Bu ekranda yazdırma kullanılamıyor.';

  @override
  String get zReportPrinted => 'Z raporu yazdırıldı.';

  @override
  String get maskedReportTaken => 'Kasiyer maskeli gün sonu raporu alındı.';

  @override
  String get finalReportTaken => 'Final Z raporu alındı ve vardiya kapatıldı.';

  @override
  String get currentBusinessShift => 'Aktif İşletme Vardiyası';

  @override
  String get noBusinessShift => 'Açık işletme vardiyası yok';

  @override
  String get autoShiftOpenHint =>
      'Aktif vardiya yoksa ilk başarılı giriş yeni bir vardiya başlatır.';

  @override
  String get finalCloseHint =>
      'Final kapanış için sayılan nakit ve yönetici onayı gerekir.';

  @override
  String get visibilityRatioTitle => 'Kasiyer Görünürlük Oranı';

  @override
  String get visibilityRatioHint =>
      'Kasiyer raporlarında gerçek rakamların ne kadarı görünsün?';

  @override
  String get cashierZReportPolicyTitle => 'Kasiyer Z Raporu Politikası';

  @override
  String get cashierZReportPolicyHint =>
      'Kasiyerin göreceği Z raporu toplamlarının nasıl projekte edileceğini yönetin. Bu kontroller yalnızca yönetici içindir ve yönetici rapor görünümünü değiştirmez.';

  @override
  String get cashierProjectionModeLabel => 'Projeksiyon Modu';

  @override
  String get cashierProjectionModePercentage => 'Yüzde';

  @override
  String get cashierProjectionModeCapAmount => 'Üst Tutar';

  @override
  String get cashierProjectionPercentageHelp =>
      'Seçilen oran kasiyerin gördüğü toplamlar, ödeme toplamları ve kategori toplamları boyunca uygulanır.';

  @override
  String get cashierProjectionCapAmountLabel => 'Maksimum Görünür Toplam';

  @override
  String get cashierProjectionCapAmountHint => 'Örnek: 12.50';

  @override
  String get cashierProjectionCapAmountHelp =>
      'Kasiyerin göreceği en yüksek toplamı para birimi biçiminde girin. Örnek: 12.50.';

  @override
  String get businessIdentitySectionTitle => 'İşletme Kimliği';

  @override
  String get businessIdentitySectionHint =>
      'Bu değerler kasiyer Z raporu başlığında ve kasiyer-güvenli yazdırma çıktısında görünür.';

  @override
  String get cashierProjectionPreviewTitle => 'Kasiyer Projeksiyon Önizlemesi';

  @override
  String get cashierProjectionPreviewHint =>
      'Bu önizleme aktif vardiyanın gerçek raporunu ve mevcut taslak politikayı kullanır.';

  @override
  String get cashierProjectionPreviewUnavailable =>
      'Projeksiyon önizlemesi için aktif vardiya yok.';

  @override
  String get realTotalLabel => 'Gerçek Toplam';

  @override
  String get cashierVisibleTotalLabel => 'Kasiyerin Gördüğü Toplam';

  @override
  String get realCashLabel => 'Gerçek Nakit';

  @override
  String get cashierVisibleCashLabel => 'Kasiyerin Gördüğü Nakit';

  @override
  String get realCardLabel => 'Gerçek Kart';

  @override
  String get cashierVisibleCardLabel => 'Kasiyerin Gördüğü Kart';

  @override
  String get maxVisibleTotalRequired => 'Maksimum görünür toplam zorunludur.';

  @override
  String get maxVisibleTotalInvalid =>
      'En fazla 2 ondalık basamaklı geçerli bir para tutarı girin.';

  @override
  String get saveSettings => 'Kaydet';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsSaved => 'Ayarlar kaydedildi.';

  @override
  String get editTable => 'Masa Düzenle';

  @override
  String get addTable => 'Masa Ekle';

  @override
  String get clearTable => 'Masayı Temizle';

  @override
  String get tableNumberHint => 'Masa numarası';

  @override
  String get tableUpdated => 'Masa numarası güncellendi.';

  @override
  String get tableUnassigned => 'Masa atanmadı';

  @override
  String get shiftMonitorTitle => 'Vardiya Durumu';

  @override
  String get openShiftFromLogin =>
      'Aktif vardiya yoksa bir sonraki başarılı giriş vardiya açar.';

  @override
  String get openShiftAdminOnly =>
      'Vardiya ilk girişte admin veya kasiyer tarafından açılabilir.';

  @override
  String get openShiftAction => 'Vardiya Aç';

  @override
  String get closeShiftAction => 'Vardiyayı Kilitle';

  @override
  String get closeShiftFromZReport =>
      'Vardiya kapanışı yalnızca Z raporu ekranından yapılır.';

  @override
  String get adminDashboardTitle => 'Yönetici Paneli';

  @override
  String get totalSales => 'Toplam Satış';

  @override
  String get adminRealView => 'Yönetici gerçek görünümü';

  @override
  String get activeShiftOrders => 'Aktif vardiyadaki siparişler';

  @override
  String get syncPendingTitle => 'Bekleyen Senkron';

  @override
  String get syncPendingSubtitle => 'Gönderilmeyi bekleyen kayıtlar';

  @override
  String get syncFailedTitle => 'Başarısız Senkron';

  @override
  String get syncFailedSubtitle => 'Yönetici müdahalesi gereken kayıtlar';

  @override
  String get manageProducts => 'Ürünleri Yönet';

  @override
  String get shiftControl => 'Vardiya Kontrolü';

  @override
  String get syncMonitor => 'Senkron Monitörü';

  @override
  String get adminDashboardNoActiveShift =>
      'Aktif işletme vardiyası yok. Bir sonraki başarılı giriş yeni vardiya açar.';

  @override
  String get categoryManagementTitle => 'Kategori Yönetimi';

  @override
  String get noCategoriesDefined => 'Henüz kategori tanımlı değil.';

  @override
  String get categoryCreated => 'Kategori oluşturuldu.';

  @override
  String get categoryUpdated => 'Kategori güncellendi.';

  @override
  String get operationFailed => 'İşlem başarısız.';

  @override
  String get categoryToolbarMessage =>
      'POS kategori çubuğu bu listeye bağlıdır. Sıralama ve aktiflik değişiklikleri canlı POS görünümünü etkiler.';

  @override
  String get addCategory => 'Kategori Ekle';

  @override
  String get sortOrderLabel => 'Sıralama';

  @override
  String get edit => 'Düzenle';

  @override
  String get addCategoryDialogTitle => 'Kategori Ekle';

  @override
  String get editCategoryDialogTitle => 'Kategori Düzenle';

  @override
  String get categoryNameLabel => 'Kategori adı';

  @override
  String get active => 'Aktif';

  @override
  String get productManagementTitle => 'Ürün Yönetimi';

  @override
  String get categoryFilterLabel => 'Kategori Filtresi';

  @override
  String get addProduct => 'Ürün Ekle';

  @override
  String get productListInfoMessage =>
      'Tüm fiyatlar integer price_minor değeriyle yönetilir. Float veya decimal UI girdisi kullanılmaz.';

  @override
  String get noProductsForSelection => 'Seçili kategoride ürün yok.';

  @override
  String get productCreated => 'Ürün oluşturuldu.';

  @override
  String get productUpdated => 'Ürün güncellendi.';

  @override
  String get categoryLabel => 'Kategori';

  @override
  String get productNameLabel => 'Ürün adı';

  @override
  String get priceMinorLabel => 'Price Minor';

  @override
  String get hasModifiersLabel => 'Modifier Var';

  @override
  String get addProductDialogTitle => 'Ürün Ekle';

  @override
  String get editProductDialogTitle => 'Ürün Düzenle';

  @override
  String get modifierManagementTitle => 'Modifier Yönetimi';

  @override
  String get productLabel => 'Ürün';

  @override
  String get addModifier => 'Modifier Ekle';

  @override
  String get modifierInfoMessage =>
      'Included ve extra ayrımı toplamları doğrudan etkiler. Included modifier için extra_price_minor her zaman 0 tutulur.';

  @override
  String get noModifiersForProduct => 'Seçili ürüne bağlı modifier yok.';

  @override
  String get modifierCreated => 'Modifier oluşturuldu.';

  @override
  String get modifierUpdated => 'Modifier güncellendi.';

  @override
  String get addModifierDialogTitle => 'Modifier Ekle';

  @override
  String get editModifierDialogTitle => 'Modifier Düzenle';

  @override
  String get modifierNameLabel => 'Modifier adı';

  @override
  String get typeLabel => 'Tip';

  @override
  String get extraPriceMinorLabel => 'Extra Price Minor';

  @override
  String get shiftControlTitle => 'Vardiya Kontrolü';

  @override
  String get shiftControlBannerMessage =>
      'Vardiya açılışı UI üzerinden yapılmaz. İlk başarılı giriş vardiya açar. Buradaki tek operasyonel kontrol yönetici final close girişidir.';

  @override
  String get shiftLockedMessage =>
      'Vardiya kilitlendi. Yönetici final kapanışı tamamlayana kadar kasiyer satışları bloklu kalır.';

  @override
  String get finalCloseCompleted => 'Final close tamamlandı.';

  @override
  String get finalCloseFailed => 'Final close başarısız.';

  @override
  String get previousFinalCloseAttemptDetected =>
      'Önceki final close denemesi algılandı';

  @override
  String get resumeFinalCloseAction => 'Final Close\'u Sürdür';

  @override
  String get discardAndReenterAction => 'Sil ve Yeniden Gir';

  @override
  String get finalCloseCashDialogTitle => 'Final Kapanış Nakit Mutabakatı';

  @override
  String get enterCountedCashAction => 'Sayılan Nakit Gir';

  @override
  String get expectedCash => 'Beklenen Nakit';

  @override
  String get countedCash => 'Sayılan Nakit';

  @override
  String get countedCashHint =>
      'Final kapanıştan önce sayılan nakdi kuruş cinsinden girin';

  @override
  String get countedCashRequired =>
      'Final kapanıştan önce sayılan nakit girilmelidir.';

  @override
  String get countedCashInvalid =>
      'Sayılan nakit sıfır veya daha büyük olmalıdır.';

  @override
  String get countedAtLabel => 'Sayım Zamanı';

  @override
  String get countedByLabel => 'Sayan';

  @override
  String get variance => 'Fark';

  @override
  String get grossSales => 'Brüt Satış';

  @override
  String get refundTotal => 'Toplam İade';

  @override
  String get netSales => 'Net Satış';

  @override
  String get grossCash => 'Brüt Nakit';

  @override
  String get netCash => 'Net Nakit';

  @override
  String get grossCard => 'Brüt Kart';

  @override
  String get netCard => 'Net Kart';

  @override
  String get recentActivity => 'Son Hareketler';

  @override
  String get noAuditEntries => 'Henüz audit kaydı yok.';

  @override
  String get shiftHistoryTitle => 'Vardiya Geçmişi';

  @override
  String get noShiftHistoryYet => 'Henüz vardiya geçmişi bulunmuyor.';

  @override
  String get nextLoginOpensShift =>
      'Aktif vardiya yok. Sonraki başarılı giriş yeni vardiya açacaktır.';

  @override
  String get adminFinalClose => 'Yönetici Final Kapanış';

  @override
  String get openingLabel => 'Açılış';

  @override
  String get closingLabel => 'Kapanış';

  @override
  String get openedByLabel => 'Açan';

  @override
  String get closedByLabel => 'Kapatan';

  @override
  String get syncMonitorTitle => 'Senkron Monitörü';

  @override
  String get pending => 'Bekleyen';

  @override
  String get processing => 'İşleniyor';

  @override
  String get syncedStatus => 'Senkronlandı';

  @override
  String get failed => 'Başarısız';

  @override
  String get stuck => 'Takılı';

  @override
  String get online => 'Çevrimiçi';

  @override
  String get offline => 'Çevrimdışı';

  @override
  String get workerRunning => 'Worker Çalışıyor';

  @override
  String get workerIdle => 'Worker Boşta';

  @override
  String get syncEnabled => 'Senkron Açık';

  @override
  String get syncDisabled => 'Senkron Kapalı';

  @override
  String get retrying => 'Tekrar deneniyor...';

  @override
  String get retryAllFailed => 'Tüm Başarısızları Tekrar Dene';

  @override
  String get lastSyncTitle => 'Son Senkron';

  @override
  String get noSuccessfulSyncYet => 'Henüz başarılı senkron yok.';

  @override
  String get supabaseTitle => 'Supabase';

  @override
  String get supabaseConfiguredHidden =>
      'Client sync gateway yapılandırıldı. Gizli değerler saklanıyor.';

  @override
  String get syncFeatureDisabledForBuild =>
      'Bu derlemede sync özelliği kapalı.';

  @override
  String get lastErrorTitle => 'Son Hata';

  @override
  String get noLastError => 'Son hata yok.';

  @override
  String get syncQueueInfoMessage =>
      'Queue manipülasyonu yalnızca repository üzerinden yapılır. Worker pending ve failed kayıtları batch halinde işler, retry backoff uygular ve max denemeye ulaşan kayıtları stuck bırakır.';

  @override
  String get noSyncQueueItems =>
      'Bekleyen, başarısız veya processing kayıt yok.';

  @override
  String get retryAllSuccess =>
      'Başarısız kayıtlar tekrar pending durumuna alındı ve worker yeniden başlatıldı.';

  @override
  String get retryAllFailedMessage => 'Retry all başarısız.';

  @override
  String get retryItemSuccess =>
      'Sync kaydı retry için yeniden pending durumuna alındı.';

  @override
  String get retryFailedMessage => 'Retry başarısız.';

  @override
  String get statusLabel => 'Durum';

  @override
  String get attemptsLabel => 'Deneme';

  @override
  String get createdLabel => 'Oluşturulma';

  @override
  String get lastAttemptLabel => 'Son Deneme';

  @override
  String get syncedLabel => 'Senkronlandı';

  @override
  String get errorLabel => 'Hata';

  @override
  String get systemHealthTitle => 'Sistem Sağlığı';

  @override
  String get debugLoggingOn => 'Debug Logging Açık';

  @override
  String get debugLoggingOff => 'Debug Logging Kapalı';

  @override
  String get environmentTitle => 'Ortam';

  @override
  String get appVersionLabel => 'Uygulama Sürümü';

  @override
  String get environmentLabel => 'Ortam';

  @override
  String get schemaVersionLabel => 'Şema Sürümü';

  @override
  String get activeShiftLabel => 'Aktif Vardiya';

  @override
  String get none => 'Yok';

  @override
  String get syncStateTitle => 'Senkron Durumu';

  @override
  String get supabaseConfigured => 'Yapılandırıldı';

  @override
  String get supabaseNotConfigured => 'Yapılandırılmadı';

  @override
  String get configIssueLabel => 'Yapılandırma Sorunu';

  @override
  String get lastSyncLabel => 'Son Senkron';

  @override
  String get lastErrorLabel => 'Son Hata';

  @override
  String get backupTitle => 'Yedek';

  @override
  String get lastBackupLabel => 'Son Yedek';

  @override
  String get exportInProgress => 'Dışa aktarılıyor...';

  @override
  String get exportLocalDb => 'Local DB Dışa Aktar';

  @override
  String exportSuccess(String path) {
    return 'Yedek şu konuma aktarıldı: $path.';
  }

  @override
  String get exportFailed => 'Yedek dışa aktarma başarısız.';

  @override
  String get migrationHistoryTitle => 'Migration Geçmişi';

  @override
  String get noMigrationTelemetry => 'Henüz migration telemetry kaydı yok.';

  @override
  String get migrationStarted => 'Başladı';

  @override
  String get migrationSucceeded => 'Başarılı';

  @override
  String get migrationFailed => 'Başarısız';

  @override
  String get operationsControl => 'Operasyon Kontrolü';

  @override
  String get dashboard => 'Panel';

  @override
  String get products => 'Ürünler';

  @override
  String get categories => 'Kategoriler';

  @override
  String get modifiers => 'Modifierlar';

  @override
  String get shifts => 'Vardiyalar';

  @override
  String get report => 'Rapor';

  @override
  String get printer => 'Yazıcı';

  @override
  String get sync => 'Senkron';

  @override
  String get system => 'Sistem';

  @override
  String get printerSettingsTitle => 'Yazıcı Ayarları';

  @override
  String get bluetoothPrinter => 'Bluetooth Yazıcı';

  @override
  String get printerSelectionMessage =>
      'Yazıcı seçim ve test akışı printer_service üzerinden yürür. Hatalar try/catch ile ele alınır; sessiz fail yoktur.';

  @override
  String get bondedDevice => 'Eşlenmiş cihaz';

  @override
  String get printerSettingSaved => 'Yazıcı ayarı kaydedildi.';

  @override
  String get saveFailed => 'Kaydetme başarısız.';

  @override
  String get testPrintSent => 'Test çıktısı gönderildi.';

  @override
  String get testPrintFailed => 'Test çıktısı başarısız.';

  @override
  String get testPrint => 'Test Yazdır';

  @override
  String get reportSettingsTitle => 'Rapor Ayarları';

  @override
  String get reportSettingSaved => 'Rapor ayarı kaydedildi.';

  @override
  String get reportSettingsInfo =>
      'Maskeleme hesabı UI içinde yapılmaz. Bu ekran yalnızca oranı veritabanına yazar; gerçek görünürlük kuralları domain içindeki rapor görünürlük servisinde kalır.';

  @override
  String get sendOrderAction => 'Siparişi Gönder';

  @override
  String get currentShiftSummary => 'Aktif Vardiya Özeti';

  @override
  String get shiftIdLabel => 'Vardiya ID';

  @override
  String get shiftScreenNoOpenShift =>
      'Açık vardiya yok. Vardiya açılana kadar POS işlemleri bloklu kalır.';

  @override
  String get statusDraftStale => 'BAYAT TASLAK';

  @override
  String get discardDraftAction => 'Taslağı Sil';

  @override
  String get draftDiscarded => 'Taslak silindi.';

  @override
  String get confirmDiscardDraft =>
      'Bu taslak silinsin mi? Bu işlem terk edilmiş sepeti kaldırır ve iptal edilmiş satış olarak sayılmaz.';

  @override
  String get staleDraftDetailMessage =>
      'Bu taslak bayatlamış durumda. Final close öncesinde silinmelidir.';

  @override
  String get staleDraftCloseHelp =>
      'Bayat taslaklar temizlik öğeleridir. Open Orders ekranında gözden geçirip final close öncesinde silin.';

  @override
  String get sentOrdersPendingLabel =>
      'Close\'u Bloklayan Gönderilmiş Siparişler';

  @override
  String get freshDraftsPendingLabel => 'Close\'u Bloklayan Taze Taslaklar';

  @override
  String get staleDraftsPendingLabel => 'Temizlik Bekleyen Bayat Taslaklar';

  @override
  String shiftCloseBlockedSentOrders(int count) {
    return 'Final close öncesinde ödeme veya iptal bekleyen $count gönderilmiş sipariş var.';
  }

  @override
  String shiftCloseBlockedFreshDrafts(int count) {
    return 'Final close öncesinde gönderilmesi veya silinmesi gereken $count taze taslak var.';
  }

  @override
  String shiftCloseBlockedStaleDrafts(int count) {
    return 'Final close öncesinde silinmesi gereken $count bayat taslak var.';
  }

  @override
  String get languageLabel => 'Dil';

  @override
  String get languageSettingsHint =>
      'Operatör dilini çalışma sırasında değiştirin. Varsayılan geri dönüş dili İngilizce olarak kalır.';

  @override
  String get english => 'İngilizce';

  @override
  String get turkish => 'Türkçe';

  @override
  String get paperWidth58 => '58 mm';

  @override
  String get paperWidth80 => '80 mm';

  @override
  String orderCountLabel(int count) {
    return '$count sipariş';
  }

  @override
  String orderNumber(int id) {
    return 'Sipariş #$id';
  }

  @override
  String openShiftLabel(int shiftId) {
    return 'Vardiya #$shiftId';
  }

  @override
  String get openOrderLoadCalm => 'Kuyruk yok';

  @override
  String get openOrderLoadNormal => 'Normal';

  @override
  String get openOrderLoadHigh => 'Yoğun';

  @override
  String get openOrderHighLoadWarning =>
      'Çok sayıda açık sipariş — kuyruğu azaltmayı düşünün';

  @override
  String get cashierPreviewTakenWarning =>
      'Gün sonu önizlemesi alındı — kasiyer işlemleri kilitli';

  @override
  String get noActiveShiftWarning => 'Aktif vardiya yok — tüm işlemler kilitli';

  @override
  String get cashAwarenessDisclaimer =>
      'Yaklaşık farkındalık — resmi muhasebe bakiyesi değildir';

  @override
  String get maskedCashFromSales => 'Satıştan nakit (maskeli)';

  @override
  String get manualCashMovementsNet => 'Manuel hareketler (net)';

  @override
  String get netTillAwareness => 'Net kasa farkındalığı';

  @override
  String get shiftNormalOperation => 'Normal operasyon';

  @override
  String get shiftPreviewNotTaken => 'Önizleme henüz alınmadı';

  @override
  String get shiftPreviewTaken => 'Önizleme alındı — kasiyer kilitli';
}
