from typing import Optional
from django.db.models import QuerySet
from core_api.models import UniversalResource, UniversalAsset, User

def get_user_resources(user: User, domain: Optional[str] = None, resource_type: Optional[str] = None) -> QuerySet[UniversalResource]:
    """
    SY-2139 Protocol: Strict Multi-tenancy Query.
    يمنع إطلاقا جلب موارد لا يملكها المستخدم الحالي.
    """
    qs = UniversalResource.objects.filter(owner=user)
    
    if domain:
        qs = qs.filter(domain=domain)
    if resource_type:
        qs = qs.filter(resource_type=resource_type)
        
    return qs

def get_user_assets(user: User, domain: Optional[str] = None) -> QuerySet[UniversalAsset]:
    """
    SY-2139 Protocol: جلب الملفات الخاصة بالمستخدم فقط.
    """
    qs = UniversalAsset.objects.filter(owner=user)
    if domain:
        qs = qs.filter(domain=domain)
    return qs