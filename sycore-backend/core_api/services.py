from typing import Dict, Any
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404
from .models import User, UniversalResource, UniversalAsset, DomainPolicy

def notify_user_realtime(user_id, event_type, payload):
    """ إرسال الإشعار الفوري للمستخدم عبر قنوات الاتصال الخاصة به فقط """
    channel_layer = get_channel_layer()
    if channel_layer:
        async_to_sync(channel_layer.group_send)(
            f'user_{user_id}',
            {
                'type': 'resource_event',
                'payload': {'event': event_type, 'data': payload}
            }
        )

# ----------------- الإضافة الجوهرية (البوابة الأمنية) -----------------
def enforce_policy_gate(project_id: str, domain_name: str, requested_clearance: str):
    """
    SY-2139 Protocol Component: Policy Immutability Gate.
    Trust on First Use: يقفل الدومين على التشفير المطلوب أول مرة، ويرفض أي محاولة لتغييره لاحقاً.
    """
    # البحث عن سياسة هذا الدومين أو إنشائها إن لم تكن موجودة
    policy, created = DomainPolicy.objects.get_or_create(
        project_id=project_id,
        name=domain_name,
        defaults={'security_clearance': requested_clearance}
    )
    
    # إذا كانت السياسة موجودة مسبقاً، نتحقق من أن التشفير المرسل يطابق التشفير المحفوظ
    if not created and policy.security_clearance != requested_clearance:
        raise PermissionDenied(
            f"[SY-2139 Data Poisoning Alert] Domain '{domain_name}' is locked to "
            f"'{policy.security_clearance}'. Cannot accept '{requested_clearance}' data."
        )
# ----------------------------------------------------------------------


# --- لاحظ تمرير project_id و security_clearance ---
def create_universal_resource(*, project_id: str, user: User, domain: str, security_clearance: str, resource_type: str, data: Dict[str, Any]) -> UniversalResource:
    
    # 1. تفعيل حارس البوابة قبل إنشاء أي شيء
    enforce_policy_gate(project_id, domain, security_clearance)

    # 2. إنشاء البيانات مع ربطها بالمشروع
    resource = UniversalResource(
        project_id=project_id,
        owner=user,
        domain=domain,
        resource_type=resource_type,
        data=data
    )
    resource.full_clean()
    resource.save()
    
    # 3. بث الإشعار الفوري
    notify_user_realtime(user.id, 'resource.created', {
        'id': str(resource.id),
        'project_id': resource.project_id,
        'domain': resource.domain,
        'type': resource.resource_type,
        'data': resource.data
    })
    
    return resource

def update_universal_resource(*, project_id: str, user: User, resource_id: str, domain: str = None, security_clearance: str = None, data: Dict[str, Any] = None) -> UniversalResource:
    # 1. جلب المورد مع التأكد من المشروع والمالك
    resource = get_object_or_404(UniversalResource, id=resource_id, owner=user, project_id=project_id)
    
    # 2. إذا أراد المطور تغيير النطاق، يجب التحقق من البوابة الأمنية
    if domain is not None:
        if security_clearance is None:
            raise Exception("عند تحديث الدومين، يجب تمرير نوع الحماية security_clearance!")
        # تفعيل حارس البوابة على الدومين الجديد (أو الحالي إذا اختلفت السياسة خطأً)
        enforce_policy_gate(project_id, domain, security_clearance)
        resource.domain = domain
    
    # 3. تحديث البيانات (الـ JSON Payload)
    if data is not None:
        resource.data = data
        
    resource.full_clean()
    resource.save()
    
    notify_user_realtime(user.id, 'resource.updated', {
        'id': str(resource.id),
        'domain': resource.domain,
        'data': resource.data
    })
    
    return resource

def delete_universal_resource(user, project_id: str, resource_id: str) -> bool:
    """
    حذف المورد مع مراعاة العزل البيئي (Tenancy Isolation).
    """
    resource = get_object_or_404(UniversalResource, id=resource_id, project_id=project_id)
    
    # التحقق من الصلاحيات: المالك حصراً أو مدير النظام
    if resource.owner != user and not user.is_superuser:
        raise PermissionDenied("You do not have permission to delete this resource.")
    
    resource.delete()
    return True

# --- قسم الملفات (Assets) ---

def upload_universal_asset(*, project_id: str, user: User, domain: str, security_clearance: str, file_obj: Any) -> Any:
    # 1. التحقق من الحظر الشامل
    if user.is_upload_banned:
        raise Exception("تم إيقاف صلاحية رفع الملفات لحسابك من قبل النظام.")
    
    # 2. التحقق من الحجم الأقصى للملف الذي حدده الأدمن (التحويل من ميغا إلى بايت)
    max_bytes = user.max_upload_size_mb * 1024 * 1024
    if hasattr(file_obj, 'size') and file_obj.size > max_bytes:
        raise Exception(f"حجم الملف يتجاوز الحد المسموح لك ({user.max_upload_size_mb} MB).")
    
    # 3. التحقق من الحد الأقصى لعدد الملفات
    current_asset_count = UniversalAsset.objects.filter(owner=user, project_id=project_id).count()
    if current_asset_count >= user.max_total_assets:
        raise Exception(f"لقد وصلت للحد الأقصى المسموح لك من الملفات ({user.max_total_assets}).")

    # 4. 🔴 تفعيل حارس السياسة للملفات أيضاً! (الملفات بيانات بالنهاية)
    enforce_policy_gate(project_id, domain, security_clearance)

    asset = UniversalAsset(
        project_id=project_id,
        owner=user,
        domain=domain,
        file=file_obj,
        mimetype=file_obj.content_type if hasattr(file_obj, 'content_type') else 'application/octet-stream',
        size=file_obj.size if hasattr(file_obj, 'size') else 0
    )
    asset.full_clean()
    asset.save()
    
    notify_user_realtime(user.id, 'asset.uploaded', {
        'id': str(asset.id),
        'project_id': asset.project_id,
        'domain': asset.domain,
        'mimetype': asset.mimetype,
        'size': asset.size
    })
    
    return asset

def update_universal_asset(*, project_id: str, user: User, asset_id: str, domain: str = None, security_clearance: str = None, file_obj: Any = None) -> Any:
    """ تحديث بيانات أو محتوى الملف مع الاحتفاظ بنفس المُعرّف ID """
    asset = get_object_or_404(UniversalAsset, id=asset_id, project_id=project_id)
    
    # 1. التحقق من الصلاحيات: المالك حصراً
    if asset.owner != user and not user.is_superuser:
        raise PermissionDenied("You do not have permission to update this asset.")
        
    # 2. تحديث النطاق (ومعه سياسة التشفير إن لزم الأمر)
    if domain is not None:
        # إذا حاول تغيير الـ Domain إلى دومين جديد أو موجود يجب تطبيق السياسة
        if security_clearance is None:
            raise Exception("عند تحديث الدومين لملف، يجب تمرير security_clearance لهذا الدومين!")
        enforce_policy_gate(project_id, domain, security_clearance)
        asset.domain = domain
        
    # 3. تحديث الملف الفعلي إذا تم رفع ملف جديد
    if file_obj is not None:
        # التحقق من القيود قبل قبول الملف الجديد
        if user.is_upload_banned:
            raise Exception("تم إيقاف صلاحية رفع الملفات لحسابك.")
            
        max_bytes = user.max_upload_size_mb * 1024 * 1024
        if hasattr(file_obj, 'size') and file_obj.size > max_bytes:
            raise Exception(f"حجم الملف يتجاوز الحد المسموح لك ({user.max_upload_size_mb} MB).")
            
        # مسح الملف الفعلي القديم من القرص لتوفير المساحة
        if asset.file:
            asset.file.delete(save=False)
            
        # إسناد الملف الجديد
        asset.file = file_obj
        asset.mimetype = file_obj.content_type if hasattr(file_obj, 'content_type') else 'application/octet-stream'
        asset.size = file_obj.size if hasattr(file_obj, 'size') else 0

    asset.full_clean()
    asset.save()
    
    # الإشعار المباشر عبر الويب سوكيت
    notify_user_realtime(user.id, 'asset.updated', {
        'id': str(asset.id),
        'domain': asset.domain,
        'mimetype': asset.mimetype,
        'size': asset.size
    })
    
    return asset

def delete_universal_asset(user, project_id: str, asset_id: str) -> bool:
    """
    حذف الملف من قاعدة البيانات ومن وحدة التخزين (Storage).
    """
    asset = get_object_or_404(UniversalAsset, id=asset_id, project_id=project_id)
    
    # التحقق من الصلاحيات: المالك حصراً أو مدير النظام
    if asset.owner != user and not user.is_superuser:
        raise PermissionDenied("You do not have permission to delete this asset.")
    
    # حذف الملف الفعلي من نظام الملفات قبل حذف السجل من قاعدة البيانات
    if asset.file:
        asset.file.delete(save=False)
        
    asset.delete()
    
    # إشعار بعد الحذف
    notify_user_realtime(user.id, 'asset.deleted', {
        'id': asset_id
    })
    
    return True

def create_user(*, username: str, password: str, email: str = '') -> User:
    """ SY-2139 Protocol: إنشاء مستخدم جديد عبر الـ API """
    if User.objects.filter(username=username).exists():
        raise Exception('اسم المستخدم هذا موجود مسبقاً.')
    
    # يتم تشفير كلمة المرور تلقائياً داخل create_user
    user = User.objects.create_user(
        username=username,
        email=email,
        password=password
    )
    return user

def admin_manage_user(
    admin_user: User, 
    target_user_id: str, 
    username: str = None, 
    email: str = None, 
    password: str = None,
    is_active: bool = None,
    is_staff: bool = None,
    is_superuser: bool = None,
    is_upload_banned: bool = None, 
    max_upload_size_mb: int = None, 
    max_total_assets: int = None
) -> User:
    """
    دالة خاصة بالـ SYCORE Admin للتحكم الشامل ببيانات أي مستخدم.
    """
    # 1. التحقق من الصلاحيات الإدارية المطلقة
    if not admin_user.is_superuser:
        raise PermissionDenied("Only superusers can manage core user settings.")
    
    # 2. جلب المستخدم المستهدف
    target_user = get_object_or_404(User, id=target_user_id)
    
    # 3. تحديث البيانات العامة
    if username is not None:
        target_user.username = username
    if email is not None:
        target_user.email = email
    if password is not None:
        target_user.set_password(password) # التشفير التلقائي لكلمة المرور
        
    # 4. تحديث الصلاحيات الأساسية للنظام (Active, Staff, Superuser)
    if is_active is not None:
        target_user.is_active = is_active
    if is_staff is not None:
        target_user.is_staff = is_staff
    if is_superuser is not None:
        target_user.is_superuser = is_superuser
        
    # 5. تحديث خصائص حدود النظام الخاصة ببروتوكول SY-2139
    if is_upload_banned is not None:
        target_user.is_upload_banned = is_upload_banned
    if max_upload_size_mb is not None:
        target_user.max_upload_size_mb = max_upload_size_mb
    if max_total_assets is not None:
        target_user.max_total_assets = max_total_assets
        
    # حفظ الكائن بعد التغييرات
    target_user.save()
    return target_user