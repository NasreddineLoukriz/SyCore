import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// محرك SAMAM (صمام)
/// مخصص للشركات أو المجموعات الكبيرة التي تتطلب تشفيراً للمحتوى 
/// مع الحفاظ على قدرة الإدارة على الوصول للرسائل بغرض المراقبة أو التحليل.
/// يعمل عن طريق توزيع مفتاح AES أساسي (Master Key) واحد بين جميع الأعضاء.
class SamamEngine {
  final _aesCipher = AesGcm.with256bits();
  final _eccKeyExchange = X25519(); // خوارزمية التبادل لتوزيع الـ Master Key

  /// 1. إعداد التشفير في المجموعة (يتم مرة واحدة عبر حساب المدير)
  /// يقوم بتوليد مفتاح المحتوى (AES Master Key) الذي ستستخدمه الشركة كلها
  Future<SecretKey> generateCompanyMasterKey() async {
    return await _aesCipher.newSecretKey();
  }

  /// 2. تشفير رسالة داخل شبكة الشركة
  /// جميع التطبيقات (SDK) للأفراد داخل فريق الشركة تستخدم الـ Master Key المستورد
  Future<Map<String, dynamic>> encryptContent({
    required List<int> contentBytes,
    required SecretKey companyMasterKey,
  }) async {
    // تشفير سريع للمحتوى.
    final secretBox = await _aesCipher.encrypt(
      contentBytes,
      secretKey: companyMasterKey,
    );

    return {
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'cipher_text': base64Encode(secretBox.cipherText),
    };
  }

  /// 3. فك تشفير رسالة قادمة من أي عضو في الشركة
  Future<List<int>> decryptContent({
    required Map<String, dynamic> encryptedData,
    required SecretKey companyMasterKey,
  }) async {
    final secretBox = SecretBox(
      base64Decode(encryptedData['cipher_text']),
      nonce: base64Decode(encryptedData['nonce']),
      mac: Mac(base64Decode(encryptedData['mac'])),
    );

    return await _aesCipher.decrypt(
      secretBox,
      secretKey: companyMasterKey,
    );
  }

  /// 4. تغليف المفتاح الأساسي لتوزيعه على موظف جديد
  /// المدير يستخدم المفتاح العام (ECC) للموظف الجديد ليغلف له مفتاح الشركة
  Future<Map<String, dynamic>> wrapMasterKeyForUser({
    required SecretKey companyMasterKey,
    required SimplePublicKey userPublicKey, // المفتاح العام للمستخدم الجديد
    required SimpleKeyPair adminKeyPair,    // مفتاح المدير لعملية التبادل
  }) async {
    // أ- توليد مفتاح سري مشترك (Shared Secret) بين المدير والموظف (تبادل Diffie-Hellman)
    final sharedSecret = await _eccKeyExchange.sharedSecretKey(
      keyPair: adminKeyPair,
      remotePublicKey: userPublicKey,
    );

    // ب- استخراج مصفوفة بايتات مفتاح الشركة الأصلي لتغليفه
    final masterKeyBytes = await companyMasterKey.extractBytes();

    // ج- تغليف (تشفير) مفتاح الشركة باستخدام المفتاح المشترك
    final secretBox = await _aesCipher.encrypt(
      masterKeyBytes,
      secretKey: sharedSecret,
    );

    return {
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'wrapped_key': base64Encode(secretBox.cipherText),
    };
  }

  /// 5. فَك تغليف المفتاح الأساسي (الموظف الجديد يستلم مفتاح الشركة)
  /// التطبيق (SDK) للموظف يفك غلاف الرسالة التي أرسلها المدير ليستخرج المفتاح
  Future<SecretKey> unwrapMasterKeyFromAdmin({
    required Map<String, dynamic> wrappedData,
    required SimplePublicKey adminPublicKey, // المفتاح العام للمدير
    required SimpleKeyPair userKeyPair,      // المفتاح الخاص للموظف المستلم
  }) async {
    // أ- توليد نفس المفتاح السري المشترك
    final sharedSecret = await _eccKeyExchange.sharedSecretKey(
      keyPair: userKeyPair,
      remotePublicKey: adminPublicKey,
    );

    final secretBox = SecretBox(
      base64Decode(wrappedData['wrapped_key']),
      nonce: base64Decode(wrappedData['nonce']),
      mac: Mac(base64Decode(wrappedData['mac'])),
    );

    // ب- استخراج المفتاح المغلف بالفك
    final masterKeyBytes = await _aesCipher.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    // بناء كائن الـ SecretKey واستخدامه لتشفير الرسائل من الآن فصاعدا
    return SecretKey(masterKeyBytes);
  }
}