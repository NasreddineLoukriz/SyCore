from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, UniversalResource, UniversalAsset

# تسجيل نموذج المستخدم المخصص
@admin.register(User)
class CustomUserAdmin(UserAdmin):
    # الأعمدة التي ستظهر في القائمة الرئيسية للمستخدمين
    list_display = ('username', 'email', 'is_staff', 'is_upload_banned', 'max_upload_size_mb', 'max_total_assets')
    
    # تحديد الحقول التي يمكن تعديلها مباشرة من القائمة (بدون الدخول للملفات الشخصية)
    list_editable = ('is_upload_banned', 'max_upload_size_mb', 'max_total_assets')
    
    # إضافة الحقول الجديدة (SY-2139 Limits) إلى شاشة التعديل الخاصة بالمستخدم (عند الدخول للتفاصيل)
    fieldsets = UserAdmin.fieldsets + (
        ('Upload Limits (SY-2139)', {
            'fields': ('is_upload_banned', 'max_upload_size_mb', 'max_total_assets')
        }),
    )

# تسجيل نموذج الموارد الشاملة (JSON Data)
@admin.register(UniversalResource)
class UniversalResourceAdmin(admin.ModelAdmin):
    list_display = ('id', 'owner', 'domain', 'resource_type', 'created_at')
    list_filter = ('domain', 'resource_type')
    search_fields = ('owner__username', 'resource_type')

# تسجيل نموذج الملفات الشاملة (Files)
@admin.register(UniversalAsset)
class UniversalAssetAdmin(admin.ModelAdmin):
    list_display = ('id', 'owner', 'domain', 'file', 'size', 'created_at')
    list_filter = ('domain',)
    search_fields = ('owner__username',)
