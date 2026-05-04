import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// محرك JAHR (جهر)
/// مخصص للبيانات والمناشير العامة.
/// لا يشفّر المحتوى (يُبقي النص مقروءاً)، ولكنه يولّد "بصمة (Hash)" 
/// ويوقعها رقمياً لضمان عدم التلاعب وإثبات هوية الناشر.
class JahrEngine {
  // استخدام خوارزمية التوقيع الرقمي حسب المواصفات في بروتوكول SY-2139
  final Ed25519 _ed25519 = Ed25519();
  final Sha256 _sha256 = Sha256();

  /// 1. إعداد المحتوى للنشر: يستخرج البصمة ويوقعها
  /// يأخذ المحتوى (نص أو ملف) ومفتاح المرسل الخاص الـ Ed25519
  Future<Map<String, dynamic>> preparePublicContent({
    required List<int> contentBytes,
    required SimpleKeyPair senderKeyPair,
  }) async {
    // أ: استخراج البصمة (Hashing) للمحتوى باستخدام SHA-256
    final hash = await _sha256.hash(contentBytes);

    // ب: توقيع هذه البصمة باستخدام المفتاح الخاص Ed25519
    final signature = await _ed25519.sign(
      hash.bytes,
      keyPair: senderKeyPair,
    );

    // ج: استخراج المفتاح العام لإرساله لكي يتحقق منه الجميع
    final publicKey = await senderKeyPair.extractPublicKey();

    // إرجاع خريطة جاهزة للإرسال إلى السيرفر كـ JSON
    return {
      'content': base64Encode(contentBytes), // المحتوى كما هو بصيغة نصية (مقروء)
      'signature': base64Encode(signature.bytes), // التوقيع الرقمي
      'public_key': base64Encode(publicKey.bytes), // المفتاح العام للتحقق
      'hash': base64Encode(hash.bytes), // البصمة للرجوع السريع
    };
  }

  /// 2. قراءة المقال العام: التحقق من التوقيع قبل عرض المحتوى
  /// أي شخص (أو SDK) يحمل هذا المحتوى من الـ Server يمرره هنا للتأكد.
  Future<bool> verifyPublicContent({
    required String base64Content,
    required String base64Signature,
    required String base64PublicKey,
  }) async {
    try {
      final contentBytes = base64Decode(base64Content);
      final signatureBytes = base64Decode(base64Signature);
      final publicKeyBytes = base64Decode(base64PublicKey);

      // إعادة حساب البصمة (Hash) من المحتوى المستلم
      final hash = await _sha256.hash(contentBytes);

      // بناء هيكل المفتاح العام والتوقيع للمكتبة
      final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      final signature = Signature(signatureBytes, publicKey: publicKey);

      // التحقق من صحة التوقيع: هل هذا المفتاح العام فعلاً وقّع على هذه البصمة؟
      final isValid = await _ed25519.verify(
        hash.bytes,
        signature: signature,
      );

      return isValid; // إذا كان true، المحتوى موثوق ومجهور بسلام.
    } catch (e) {
      // أي فشل في فك التشفير أو البناء يعني أن البيانات معطوبة
      return false;
    }
  }
}