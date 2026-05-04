# محرك صَمام (SAMAM) - تشفير المجموعات والشركات

بينما `حِصْن` مصمم لأرسال رسائل لا يقرأها إلا المستلم الأصلي (1-to-1)، فإن **صَمام** مصمم لبيئات العمل (فرق الشركات/الجروبات) حيث يجب تشفير المحتوى، ولكن يجب أن تملك الشركة (الإدارة) حق الوصول إليه للرقابة أو التوجيه.

## آلية العمل (The Master Key Pattern)
يعتمد صَمام على خوارزمية `AES-GCM` لتشفير البيانات عبر "مفتاح الشركة" (Team Master Key).
هذا المفتاح يتم توليده من حساب الإدارة، ويتم **تغليفه (Wrap)** لاحقاً بمفتاح الـ `X25519` الخاص بكل موظف جديد ينضم للشركة لكي ينزل في محفظته المحلية. حينها يستطيع كل موظف التشفير وفك التشفير.

## أمثلة الاستخدام عبر المايسترو (`SycoreClient`)

**إرسال تعميم/رسالة للمجموعة:**
```dart
// يقوم بجلب مفتاح الشركة من محفظة الموظف
final companyKey = await vault.getCompanyMasterKey('MyCorpID'); 

await sycore.sendSamamMessage(
  domain: 'corporate_data',
  message: 'الرجاء اعتماد النظام المالي الجديد',
  companyMasterKey: companyKey,
);
```

**جلب وفك تشفير كل الرسائل دفعة واحدة للموظف:**
```dart
// جلب وفك تشفير كل الرسائل دفعة واحدة للموظف
final messages = await sycore.fetchAndDecryptSamamMessages(
  domain: 'corporate_data',
  companyMasterKey: companyKey,
);
```