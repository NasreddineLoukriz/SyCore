from typing import Optional
from django.db.models import QuerySet
from .models import UniversalResource, UniversalAsset, User, DomainPolicy

# ------------------- قسم الموارد (Resources) -------------------

def get_user_resources(user: User, project_id: str, domain: str = None, resource_type: str = None) -> QuerySet[UniversalResource]:
    """
    استرجاع بيانات المستخدم، مع اشتراط أن تكون ضمن Project ID الخاص به للسرية التامة.
    """
    queryset = UniversalResource.objects.filter(owner=user, project_id=project_id)
    
    if domain:
        queryset = queryset.filter(domain=domain)
        
    if resource_type:
        queryset = queryset.filter(resource_type=resource_type)
        
    return queryset.order_by('-updated_at')

def get_resource_by_id(user: User, project_id: str, resource_id: str) -> UniversalResource:
    """ استرجاع مورد واحد بالـ ID الخاص به مع ضمان انه لنفس العميل والمشروع """
    from django.shortcuts import get_object_or_404
    return get_object_or_404(UniversalResource, id=resource_id, owner=user, project_id=project_id)


# ------------------- قسم الأصول/الملفات (Assets) -------------------

def get_user_assets(user: User, project_id: str, domain: str = None) -> QuerySet[UniversalAsset]:
    """
    استرجاع ملفات المستخدم الخاصة بمشروعه.
    """
    queryset = UniversalAsset.objects.filter(owner=user, project_id=project_id)
    
    if domain:
        queryset = queryset.filter(domain=domain)
        
    return queryset.order_by('-created_at')

def get_asset_by_id(user: User, project_id: str, asset_id: str) -> UniversalAsset:
    from django.shortcuts import get_object_or_404
    return get_object_or_404(UniversalAsset, id=asset_id, owner=user, project_id=project_id)


# ------------------- قسم سياسات الدومينات (اختياري للـ SDK) -------------------

def get_domain_policy(project_id: str, domain_name: str) -> DomainPolicy:
    """
    مفيدة جداً إذا أراد الـ SDK معرفة نوع التشفير المفروض على الدومين قبل إرسال البيانات.
    """
    try:
        return DomainPolicy.objects.get(project_id=project_id, name=domain_name)
    except DomainPolicy.DoesNotExist:
        return None