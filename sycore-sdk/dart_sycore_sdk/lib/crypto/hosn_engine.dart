import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// محرك HOSN (حِصْن)
/// نظام تشفير الند للند (E2EE) صارم لا يمكن للسيرفر أو حتى الشركة الأم الوصول للبيانات.
/// يعتمد على الكفاءة (تشفير المحتوى مرة واحدة بمفتاح عشوائي متماثل) + 
/// تغليف وحماية هذا المفتاح للمرسل والمسقبل.
class HosnEngine {
  final _aesCipher = AesGcm.with256bits();
  final _eccKeyExchange = X25519(); // خوارزمية التبادل لتغليف المفاتيح

  /// 1. تغليف وتشفير الرسالة أو الملف
  /// ينتج رسالة مشفرة + قائمة بالمفاتيح المغلفة المرسلة إلى السيرفر.
  Future<Map<String, dynamic>> encryptE2EEMessage({
    required List<int> contentBytes,
    required SimpleKeyPair senderKeyPair,       // المفتاح الخاص للمرسل (أ) - ECC
    required SecretKey senderVaultKey,          // المفتاح الخاص للمحفظة للطرف (أ) - AES
    required SimplePublicKey receiverPublicKey, // المفتاح العام للمستقبل (ب) - ECC
  }) async {
    
    // الخطوة 1: توليد مفتاح رسالة عشوائي للاستعمال لمرة واحدة (Message Key)
    final messageKey = await _aesCipher.newSecretKey();
    
    // الخطوة 2: تشفير المحتوى بهذا المفتاح المستحدث
    final encryptedContentBox = await _aesCipher.encrypt(
      contentBytes,
      secretKey: messageKey,
    );
    final encryptedContentBase64 = {
      'nonce': base64Encode(encryptedContentBox.nonce),
      'mac': base64Encode(encryptedContentBox.mac.bytes),
      'cipher_text': base64Encode(encryptedContentBox.cipherText),
    };

    // استخراج بايتات مفتاح الرسالة لتغليفها
    final messageKeyBytes = await messageKey.extractBytes();

    // الخطوة 3: التغليف للطرف الدخيل (Receiver - ب)
    // التغليف يتم عبر تبادل Diffie-Hellman لإنتاج سر مشترك للتغليف
    final sharedSecretForReceiver = await _eccKeyExchange.sharedSecretKey(
      keyPair: senderKeyPair,
      remotePublicKey: receiverPublicKey,
    );
    
    final wrappedKeyForReceiverBox = await _aesCipher.encrypt(
      messageKeyBytes,
      secretKey: sharedSecretForReceiver,
    );
    final wrappedKeyForReceiver = {
      'nonce': base64Encode(wrappedKeyForReceiverBox.nonce),
      'mac': base64Encode(wrappedKeyForReceiverBox.mac.bytes),
      'wrapped_key': base64Encode(wrappedKeyForReceiverBox.cipherText),
    };

    // الخطوة 4: التغليف للمالك الأصلي (Sender - أ)
    // نغلف المفتاح بمفتاح محفظة المرسل حتى لو فقد جهازه يسترجع رسائله بالـ Password الخاصة به
    final wrappedKeyForSenderBox = await _aesCipher.encrypt(
      messageKeyBytes,
      secretKey: senderVaultKey,
    );
    final wrappedKeyForSender = {
      'nonce': base64Encode(wrappedKeyForSenderBox.nonce),
      'mac': base64Encode(wrappedKeyForSenderBox.mac.bytes),
      'wrapped_key': base64Encode(wrappedKeyForSenderBox.cipherText),
    };

    // 5. المخرجات التي سترسل كـ JSON إلى السيرفر "الغبي"
    return {
      'content': encryptedContentBase64,
      'keys': {
        'receiver': wrappedKeyForReceiver,
        'sender': wrappedKeyForSender,
      }
    };
  }

  /// 2. فك التشفير: عندما يقوم المستقبل (ب) بجلب الرسالة من السيرفر
  Future<List<int>> decryptE2EEResageByReceiver({
    required Map<String, dynamic> payloadFromServer,
    required SimpleKeyPair receiverKeyPair,     // المفتاح الخاص للمستلم (ب) - ECC
    required SimplePublicKey senderPublicKey,   // المفتاح العام للمرسل (أ) - ECC
  }) async {
    // 1. توليد المفتاح السري المشترك
    final sharedSecret = await _eccKeyExchange.sharedSecretKey(
      keyPair: receiverKeyPair,
      remotePublicKey: senderPublicKey,
    );

    // 2. الوصول للمفتاح المغلف الخاص بالمستقبل
    final wrappedKeyData = payloadFromServer['keys']['receiver'];
    final wrappedKeyBox = SecretBox(
      base64Decode(wrappedKeyData['wrapped_key']),
      nonce: base64Decode(wrappedKeyData['nonce']),
      mac: Mac(base64Decode(wrappedKeyData['mac'])),
    );

    // 3. فك الغلاف واستخراج Message Key
    final messageKeyBytes = await _aesCipher.decrypt(
      wrappedKeyBox,
      secretKey: sharedSecret,
    );
    final messageKey = SecretKey(messageKeyBytes);

    // 4. استخدام Message Key لفك تشفير المحتوى الرئيسي
    return _decryptContentSafely(payloadFromServer['content'], messageKey);
  }

  /// 3. فك التشفير الذاتي: عندما يقرأ المرسل (أ) رسالته القديمة اللي أرسلها لجهاز آخر
  Future<List<int>> decryptE2EEResageBySender({
    required Map<String, dynamic> payloadFromServer,
    required SecretKey senderVaultKey, // مفتاح المحفظة السري (AES)
  }) async {
     final wrappedKeyData = payloadFromServer['keys']['sender'];
     final wrappedKeyBox = SecretBox(
      base64Decode(wrappedKeyData['wrapped_key']),
      nonce: base64Decode(wrappedKeyData['nonce']),
      mac: Mac(base64Decode(wrappedKeyData['mac'])),
    );

    // فك الغلاف مباشرة باستخدام مفتاح المحفظة الثابت
    final messageKeyBytes = await _aesCipher.decrypt(
      wrappedKeyBox,
      secretKey: senderVaultKey,
    );
    final messageKey = SecretKey(messageKeyBytes);

    // فك التشفير للمحتوى
    return _decryptContentSafely(payloadFromServer['content'], messageKey);
  }

  // --- دالة مساعدة لفك المحتوى ---
  Future<List<int>> _decryptContentSafely(Map<String, dynamic> contentData, SecretKey key) async {
    final contentBox = SecretBox(
      base64Decode(contentData['cipher_text']),
      nonce: base64Decode(contentData['nonce']),
      mac: Mac(base64Decode(contentData['mac'])),
    );
    return await _aesCipher.decrypt(contentBox, secretKey: key);
  }
}