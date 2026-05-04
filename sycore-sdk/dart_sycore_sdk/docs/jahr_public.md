# محرك جَهْر (JAHR) - النشر العلني الموقّع

محرك **جَهْر** مُصمم للمحتوى العام (Public Data) الذي يجب أن يقرأه الجميع (كالمنشورات والمقالات)، ولكن مع ميزة "إثبات المصدر" (Non-repudiation).

بدلاً من تشفير البيانات وإخفائها، يقوم المحرك بتمريرها كنصوص Base64، لكنه يرفق معها **توقيعاً رقمياً** (Digital Signature) باستخدام خوارزمية `Ed25519`.

## آلية العمل في بروتوكول SY-2139
1. **النشر:** التطبيق يحزم النص كـ Base64 + يوقعه بالمفتاح الخاص (Ed25519 Signature Key) المحفوظ في محفظة المستخدم.
2. **التحقق (الجلاّس):** أي مستخدم أو زائر يجلب البيان من السيرفر. المحرك يستخدم الدالة الجاهزة للتحقق حسابياً بأن (النص + التوقيع + المفتاح العام للمرسل) متطابقون 100% رياضياً. لو تغير حرف واحد، يُرفض المحتوى.

## مثال على الاستخدام عبر المايسترو (`SycoreClient`)

**نشر محتوى جديد:**
```dart
final response = await sycore.publishJahrContent(
  domain: 'global_news_feed',
  content: 'تم إطلاق بروتوكول حصن بنجاح! 🚀',
);
```

**التحقق من المحتوى المُنشور:**
```dart
final isAuthentic = await jahrEngine.verifyPublicContent(
  base64Content: postFromServer['content_base64'],
  base64Signature: postFromServer['signature'],
  base64PublicKey: postFromServer['public_key'],
);
if(!isAuthentic) throw Exception("محتوى مزيف أو تم العبث به!");
```
