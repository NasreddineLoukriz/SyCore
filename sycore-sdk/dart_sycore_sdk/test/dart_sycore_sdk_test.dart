import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_sycore_sdk/dart_sycore_sdk.dart';

/// ==========================================
/// إختبارات بروتوكول SY-2139 (SDK Unit Tests)
/// ==========================================

void main() {
  group('HOSN Engine (E2EE) Tests', () {
    late HosnEngine hosn;
    final x25519 = X25519(); // خوارزمية توليد المفاتيح للاختبار

    setUp(() {
      hosn = HosnEngine();
    });

    test('Should encrypt and successfully decrypt a message as Sender & Receiver', () async {
      // 1. إعداد البيئة الوهمية (المفاتيح المحلية)
      final senderVaultKey = await SecretKeyData.random(length: 32).extract();
      final senderKeyPair = await x25519.newKeyPair(); 
      
      final receiverKeyPair = await x25519.newKeyPair(); 

      // استخراج الـ Public Keys
      final senderPublicKey = await senderKeyPair.extractPublicKey();
      final receiverPublicKey = await receiverKeyPair.extractPublicKey();

      final String originalMessage = "رسالة سرية مشفرة ببروتوكول الحصن!";
      final contentBytes = utf8.encode(originalMessage);

      // 2. التشفير بواسطة المرسل
      final payload = await hosn.encryptE2EEMessage(
        contentBytes: contentBytes,
        senderKeyPair: senderKeyPair,
        senderVaultKey: senderVaultKey,
        receiverPublicKey: receiverPublicKey,
      );

      // التأكد أن البيانات تم تغليفها ولم تعد نصاً صريحاً
      expect(payload.containsKey('content'), isTrue);
      expect(payload['keys']['sender'], isNotNull);
      expect(payload['keys']['receiver'], isNotNull);

      // 3. فك التشفير بواسطة المستقبل (Receiver)
      final decryptedByReceiver = await hosn.decryptE2EEResageByReceiver(
        payloadFromServer: payload,
        receiverKeyPair: receiverKeyPair,
        senderPublicKey: senderPublicKey,
      );
      expect(utf8.decode(decryptedByReceiver), equals(originalMessage));

      // 4. فك التشفير الذاتي بواسطة المرسل (Sender Backup)
      final decryptedBySender = await hosn.decryptE2EEResageBySender(
        payloadFromServer: payload,
        senderVaultKey: senderVaultKey,
      );
      expect(utf8.decode(decryptedBySender), equals(originalMessage));
    });
  });

  group('SAMAM Engine (Team) Tests', () {
    late SamamEngine samam;

    setUp(() {
      samam = SamamEngine();
    });

    test('Should encrypt and decrypt team content using Master Key', () async {
      final String teamMessage = "تعميم داخلي لشركة صمام";
      final contentBytes = utf8.encode(teamMessage);

      // 1. إعداد مفتاح الشركة
      final masterKey = await samam.generateCompanyMasterKey();

      // 2. التشفير
      final encryptedPayload = await samam.encryptContent(
        contentBytes: contentBytes,
        companyMasterKey: masterKey,
      );

      expect(encryptedPayload.containsKey('cipher_text'), isTrue);

      // 3. فك التشفير
      final decryptedBytes = await samam.decryptContent(
        encryptedData: encryptedPayload,
        companyMasterKey: masterKey,
      );

      expect(utf8.decode(decryptedBytes), equals(teamMessage));
    });
  });

  group('JAHR Engine (Public Signatures) Tests', () {
    late JahrEngine jahr;
    final ed25519 = Ed25519(); // خوارزمية التوقيع الرقمي

    setUp(() {
      jahr = JahrEngine();
    });

    test('Should sign public content and verify signature successfully', () async {
      // 1. توليد مفاتيح توقيع للمرسل
      final senderKeyPair = await ed25519.newKeyPair();
      // تم حذف متغير senderPublicKey لعدم استخدامه لتجنب التحذير.

      final String publicPost = "بيان عام رسمي: نعلن عن نجاح مشروعنا!";
      final contentBytes = utf8.encode(publicPost);

      // 2. النشر (تحضير المحتوى والتوقيع)
      final payload = await jahr.preparePublicContent(
        contentBytes: contentBytes,
        senderKeyPair: senderKeyPair,
      );

      // التأكد أن الـ Payload يحتوي على المحتوى والمفتاح والتوقيعات
      expect(payload.containsKey('content_base64'), isTrue);
      expect(payload.containsKey('signature'), isTrue);
      expect(payload.containsKey('public_key'), isTrue);

      // 3. التحقق (أي مستخدم آخر يقرأ المنشور من السيرفر)
      final isAuthentic = await jahr.verifyPublicContent(
        base64Content: payload['content_base64'] as String,
        base64Signature: payload['signature'] as String,
        base64PublicKey: payload['public_key'] as String,
      );

      // يجب أن يكون التوقيع صحيحاً (يطابق المحتوى وصاحب المفتاح)
      expect(isAuthentic, isTrue);

      // -- اختبار الاختراق: محاولة تزييف المحتوى (التحقق سيفشل) --
      final hackedContentBase64 = base64Encode(utf8.encode("بيان مزيف!"));

      final isFakeAuthentic = await jahr.verifyPublicContent(
        base64Content: hackedContentBase64,
        base64Signature: payload['signature'] as String, 
        base64PublicKey: payload['public_key'] as String,
      );

      expect(isFakeAuthentic, isFalse); // يجب أن يُفضح التزييف!
    });
  });
}
