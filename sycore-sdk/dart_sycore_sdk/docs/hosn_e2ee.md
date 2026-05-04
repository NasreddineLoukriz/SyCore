# محرك حِصْن (HOSN)
يعتمد على خوارزمية `AES-GCM` لتشفير ومفتاح عشوائي للرسالة، ثم يتم تغليف مفتاح الرسالة مرتين بتبادل `X25519`:
1. مغلف بـ `SharedSecret` للمستقبل.
2. مغلف بـ `VaultKey` احتياطي للمرسل.

**مثال الإرسال:**
```dart
await sycore.sendHosnMessage(
  targetUserId: 'USER_123',
  domain: 'chat_app',
  message: 'مرحباً، هذه رسالة سرية',
);