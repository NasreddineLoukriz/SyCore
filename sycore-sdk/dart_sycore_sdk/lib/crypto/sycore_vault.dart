import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// وحدة المحفظة والهوية (Sycore Vault) المحدثة
/// مسؤولة عن توليد وإدارة وحفظ المفاتيح في الهاتف بشكل آمن.
class SycoreVault {
  // المحرك الآمن لحفظ البيانات في الجهاز (Keychain/Keystore)
  final _secureStorage = const FlutterSecureStorage();
  
  // أنظمة التشفير
  final _aesCipher = AesGcm.with256bits();
  final _eccKeyExchange = X25519();
  final _digitalSignature = Ed25519();
  
  // الاحتفاظ بالمفتاح مؤقتاً في الذاكرة العشوائية لتسريع العمليات أثناء الجلسة المفتوحة
  SecretKey? _cachedVaultKey;

  /// 1. إعداد المحفظة عند تسجيل الدخول أو الشروع لأول مرة
  /// يقوم باشتقاق المفتاح ويحفظه بأمان لتجنب طلب كلمة السر مجدداً.
  Future<void> initializeVault(String password, String salt) async {
    // استخراج المفتاح السري القوي من كلمة السر
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000, 
      bits: 256,
    );
    
    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode(salt),
    );
    
    // تحويل بايتات المفتاح إلى Base64 لتخزينها
    final keyBytes = await secretKey.extractBytes();
    final base64Key = base64Encode(keyBytes);
    
    // حفظ المفتاح في رقيقة الأمان بالهاتف (Hardware TEE)
    await _secureStorage.write(key: 'sycore_vault_master_key', value: base64Key);
    
    // حفظه في الذاكرة العشوائية لجلسة العمل الحالية
    _cachedVaultKey = secretKey;
  }

  /// 2. استرجاع مفتاح المحفظة للقيام بعمليات HOSN أو SAMAM
  /// إذا كان المستخدم قد سجل دخوله مسبقاً، سيجد المفتاح دون الحاجة للـ Password
  Future<SecretKey> getVaultKey() async {
    // 1. هل المفتاح موجود في الذاكرة؟ الأسرع!
    if (_cachedVaultKey != null) return _cachedVaultKey!;
    
    // 2. إذا أعاد تشغيل التطبيق، نجلب المفتاح من الخزنة الآمنة
    final base64Key = await _secureStorage.read(key: 'sycore_vault_master_key');
    if (base64Key == null) {
      throw Exception('Vault Key not found. User must login or initialize vault first.');
    }
    
    final keyBytes = base64Decode(base64Key);
    _cachedVaultKey = SecretKey(keyBytes);
    
    return _cachedVaultKey!;
  }
  
  /// 3. مسح المحفظة (عند تسجيل الخروج)
  Future<void> lockVault() async {
    _cachedVaultKey = null;
    await _secureStorage.delete(key: 'sycore_vault_master_key');
    // إذا كنت تخزن مفاتيح الـ ECC والـ Ed25519 هنا أيضاً، امسحها.
  }

  // ----------------------------------------------------
  // توليد المفاتيح الأخرى (نفس المنطق القديم ولكن يمكن الآن حفظها عبر secureStorage)
  
  // توليد مفاتيح ECC للمراسلات
  Future<SimpleKeyPair> generateEccMessagingKeyPair() async {
    return await _eccKeyExchange.newKeyPair();
  }

  // توليد مفاتيح التوقيع الرقمي JAHR
  Future<SimpleKeyPair> generateEd25519SignatureKeyPair() async {
    return await _digitalSignature.newKeyPair();
  }

  // توليد مفتاح الرسالة (الذي يُرمى بعد الاستخدام)
  Future<SecretKey> generateRandomMessageKey() async {
    return await _aesCipher.newSecretKey();
  }
}