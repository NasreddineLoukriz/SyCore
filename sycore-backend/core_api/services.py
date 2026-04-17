from typing import Dict, Any
from core_api.models import UniversalResource, User
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404
from .models import User, UniversalAsset

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

def create_universal_resource(*, user: User, domain: str, resource_type: str, data: Dict[str, Any]) -> UniversalResource:
    resource = UniversalResource(
        owner=user,
        domain=domain,
        resource_type=resource_type,
        data=data
    )
    resource.full_clean()
    resource.save()
    
    # 🔴 هنا يحدث السحر: بث الإشعار الفوري بعد الحفظ مباشرة!
    notify_user_realtime(user.id, 'resource.created', {
        'id': str(resource.id),
        'domain': resource.domain,
        'type': resource.resource_type,
        'data': resource.data
    })
    
    return resource

def update_universal_resource(*, user: User, resource_id: str, data: Dict[str, Any]) -> UniversalResource:
    resource = UniversalResource.objects.get(id=resource_id, owner=user)
    resource.data = data
    resource.full_clean()
    resource.save()
    
    notify_user_realtime(user.id, 'resource.updated', {
        'id': str(resource.id),
        'data': resource.data
    })
    
    return resource

def delete_universal_resource(user, resource_id: str) -> bool:
    """
    حذف المورد مع مراعاة العزل البيئي (Tenancy Isolation).
    """
    resource = get_object_or_404(UniversalResource, id=resource_id)
    
    # التحقق من الصلاحيات: المالك حصراً أو مدير النظام
    if resource.owner != user and not user.is_superuser:
        raise PermissionDenied("You do not have permission to delete this resource.")
    
    resource.delete()
    return True

def upload_universal_asset(*, user: User, domain: str, file_obj: Any) -> Any:
    # 1. التحقق من الحظر الشامل
    if user.is_upload_banned:
        raise Exception("تم إيقاف صلاحية رفع الملفات لحسابك من قبل النظام.")
    
    # 2. التحقق من الحجم الأقصى للملف الذي حدده الأدمن (التحويل من ميغا إلى بايت)
    max_bytes = user.max_upload_size_mb * 1024 * 1024
    if hasattr(file_obj, 'size') and file_obj.size > max_bytes:
        raise Exception(f"حجم الملف يتجاوز الحد المسموح لك ({user.max_upload_size_mb} MB).")
    
    # 3. التحقق من الحد الأقصى لعدد الملفات
    current_asset_count = UniversalAsset.objects.filter(owner=user).count()
    if current_asset_count >= user.max_total_assets:
        raise Exception(f"لقد وصلت للحد الأقصى المسموح لك من الملفات ({user.max_total_assets}).")

    from core_api.models import UniversalAsset
    
    asset = UniversalAsset(
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
        'domain': asset.domain,
        'mimetype': asset.mimetype,
        'size': asset.size
    })
    
    return asset

def update_universal_asset(*, user: User, asset_id: str, domain: str = None, file_obj: Any = None) -> Any:
    """ تحديث بيانات أو محتوى الملف مع الاحتفاظ بنفس المُعرّف ID """
    asset = get_object_or_404(UniversalAsset, id=asset_id)
    
    # 1. التحقق من الصلاحيات: المالك حصراً
    if asset.owner != user and not user.is_superuser:
        raise PermissionDenied("You do not have permission to update this asset.")
        
    # 2. تحديث النطاق إذا تم تمريره
    if domain is not None:
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

def delete_universal_asset(user, asset_id: str) -> bool:
    """
    حذف الملف من قاعدة البيانات ومن وحدة التخزين (Storage).
    """
    asset = get_object_or_404(UniversalAsset, id=asset_id)
    
    # التحقق من الصلاحيات: المالك حصراً أو مدير النظام
    if asset.owner != user and not user.is_superuser:
        raise PermissionDenied("You do not have permission to delete this asset.")
    
    # حذف الملف الفعلي من نظام الملفات قبل حذف السجل من قاعدة البيانات
    if asset.file:
        asset.file.delete(save=False)
        
    asset.delete()
    
    # إشعار بعد الحذف (اختياري لكنه مفيد جداً للـ Frontend)
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