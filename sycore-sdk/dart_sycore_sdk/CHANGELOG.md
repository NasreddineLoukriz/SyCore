## 0.0.2

* **Documentation & Technical Refinement | التوثيق والتحسين التقني**
* Added `doc/ai-agent-instructions.md`: Comprehensive technical guide for SY-2139 protocol integration. (إضافة دليل تقني شامل لدمج بروتوكول SY-2139)
* Clarified **Compound Identity** logic: Explicit mapping of `project_id`, `owner_id`, and `domain_name`. (توضيح منطق الهوية المركبة وربط معرف المشروع والمستعمل والنطاق)
* Documented **Policy Immutability Gate** (Trust on First Use) for SDK users. (توثيق بوابة عدم تغيير السياسات الأمنية عند أول استخدام)
* Expanded HOSN and JAHR usage examples in documentation. (توسيع أمثلة استخدام محركات حِصْن وجهر)
* Updated dependencies to their latest stable versions. (تحديث الاعتماديات إلى أحدث الإصدارات المستقرة)

## 0.0.1

* **Initial Production Release (SY-2139 Protocol Component) | الإصدار الأولي للإنتاج**
* Added **SycoreVault**: Secure local storage for ECC/Ed25519 keys using `flutter_secure_storage`. (إضافة الخزنة للتخزين الآمن للمفاتيح محلياً)
* Added **HosnEngine (堡垒)**: Implementation of 1-to-1 E2EE using X25519 and ChaCha20-Poly1305. (محرك حِصْن: تشفير طرف إلى طرف باستخدام X25519)
* Added **SamamEngine (صمام)**: Group/Team data encryption using AES-GCM and Master Key wrapping. (محرك صمام: تشفير البيانات للمجموعات والفرق)
* Added **JahrEngine (جهر)**: Public data integrity with Ed25519 digital signatures. (محرك جهر: التأكد من سلامة البيانات العامة عبر التواقيع الرقمية)
* Added **SycoreClient (The Maestro)**: Unified API client for easy integration. (إضافة العميل الموحد لتسهيل الدمج)
* Added **Real-Time Synergy**: Full WebSocket support for live domain event listening. (دعم التزامن اللحظي عبر WebSockets)

