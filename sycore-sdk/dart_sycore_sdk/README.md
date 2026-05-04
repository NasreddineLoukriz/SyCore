# Dart Sycore SDK 🛡️
مكتبة Flutter/Dart الرسمية لبروتوكول **SY-2139** (Zero-Trust Backend as a Service).

يقدم هذا الـ SDK تجربة متكاملة لتخزين ونقل البيانات مع انعدام ثقة تام (Zero-Trust) تجاه الخادم. الخادم يعمل كـ "قبو أعمى" (Dumb Server)، بينما يدير هذا الـ SDK (العميل الذكي) كل عمليات التشفير (E2EE) والتوقيع الموثوق محلياً داخل جهاز المستخدم قبل الإرسال.

## 🚀 المميزات
- **شامل وجاهز:** يربط `Network` (GraphQL Client) و `Crypto` معاً في واجهة صلبة تسمى `SycoreClient`.
- محرك **حصن (HOSN):** تشفير الند للند (E2EE 1-to-1) باستخدام `X25519` و `AES-GCM`.
- محرك **صمام (SAMAM):** تشفير المجموعات/الشركات باستخدام مفاتيح Master.
- محرك **جهر (JAHR):** نشر محتوى عمومي موقع رقمياً بـ `Ed25519` يصعب تزييفه.

## 📦 التثبيت
في ملف `pubspec.yaml`:
```yaml
dependencies:
  dart_sycore_sdk:
    path: path/to/dart_sycore_sdk
```

## 🚀 الاستخدام
```dart
import 'package:dart_sycore_sdk/dart_sycore_sdk.dart';

void main() async {
  // 1. تهيئة النظام
  final sycore = await SycoreClient.initialize(
    endpointUrl: 'https://api.myapp.com/graphql/',
    projectId: 'PROJECT_XXX',
  );

  // 2. التسجيل وتهيئة محفظة الأمان (Vault)
  // تقوم هذه الدالة بتسجيل المستخدم للسيرفر + إنشاء مفاتيح ECC/Ed25519 محلياً
  await sycore.signupAndSetupVault(
    username: 'UserA',
    password: 'SuperSecretPassword',
  );

  // 3. النشر عبر جهر (JAHR)
  await sycore.publishJahrContent(
    domain: 'public_feed',
    content: 'مرحباً بالعالم من بروتوكولنا المشفر!',
  );
}
```