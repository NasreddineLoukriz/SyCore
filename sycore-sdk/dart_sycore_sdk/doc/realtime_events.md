# الاتصال الفوري والمزامنة (Real-Time Synergy)

يوفر **SYCORE SDK** إمكانية الاستماع الحي للتغيرات التي تطرأ على قواعد البيانات (إنشاء، تعديل، حذف) عبر الـ WebSockets بدون الحاجة لعمل Reload للبيانات باستمرار. تعتمد هذه الخاصية على قنوات Django Channels من جهة الخادم.

## آلية العمل (Zero-Knowledge Privacy)
- يتم فتح قناة اتصال مشفرة ومصادق عليها باستخدام `JWT Token` الخاص بالمستخدم.
- الخادم يرسل فقط **البيانات المغلفة** وقت حدوثها.
- لن يستلم المستخدم إلا التحديثات التي تتبع لملفاته الشخصية أو نطاقات العمل المسموح له بها، لضمان أعلى درجات الأمان.

## الاستخدام عبر المايسترو (`SycoreClient`)

للتمتع بالتزامن اللحظي، يمكنك استخدام الدالة `listenToDomain` التي تعيد لك `Stream` في تطبيق Flutter الخاص بك. 

### مثال توضيحي باستخدام `StreamBuilder` في Flutter:

```dart
// افتراض أن sycore مهيأ وتم تسجيل الدخول بنجاح مسبقاً

StreamBuilder<Map<String, dynamic>>(
  // نستمع إلى التغيرات في نطاق محدد (Domain)
  stream: sycore.listenToDomain('corporate_data'),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Text('في انتظار البيانات الحية...');
    }
    
    if (snapshot.hasError) {
      return Text('حدث خطأ في الاتصال: ${snapshot.error}');
    }

    if (snapshot.hasData) {
      final realTimeData = snapshot.data!;
      // realTimeData هو عبارة عن Map يحتوي على التحديث الجديد الوافد من الخادم
      
      // مثال للتعامل مع الحدث:
      final eventType = realTimeData['event_type']; // 'created', 'updated', 'deleted'
      final resourceId = realTimeData['id'];
      
      return Text('تحديث جديد! الحدث: $eventType للمورد $resourceId');
    }
    
    return Text('لا توجد تحديثات حتى الآن.');
  },
)