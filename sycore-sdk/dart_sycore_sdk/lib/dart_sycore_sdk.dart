/// مكتبة بروتوكول SY-2139
/// (Zero-Trust Backend as a Service)

// 1. تصدير المايسترو (لأنه هو ما سيستدعيه المطور)
export 'sycore_client.dart';

// 2. تصدير الشبكة والمحفظة إذا أراد المطور التحكم المتقدم
export 'network/graphql_client.dart';
export 'crypto/sycore_vault.dart';

// تصدير المحركات التشفيرية اختيارياً
export 'crypto/hosn_engine.dart';
export 'crypto/samam_engine.dart';
export 'crypto/jahr_engine.dart';

// قمنا أيضاً بتصدير مكتبة التشفير نفسها عشان ما يضطر
// المطور يستوردها يدوياً لو أراد استعمال SecretKey مثلاً
export 'package:cryptography/cryptography.dart';
