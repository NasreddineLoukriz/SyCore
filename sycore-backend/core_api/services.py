from typing import Dict, Any
from core_api.models import UniversalResource, User

def create_universal_resource(*, user: User, domain: str, resource_type: str, data: Dict[str, Any]) -> UniversalResource:
    """
    SY-2139 Protocol: Generic Resource Creation.
    إذا كان النطاق هو HOSN، فإن الـ data يتم حفظه ككتلة مشفرة ولا يتم فحصه أبداً.
    """
    resource = UniversalResource(
        owner=user,
        domain=domain,
        resource_type=resource_type,
        data=data
    )
    resource.full_clean()
    resource.save()
    
    return resource

def update_universal_resource(*, user: User, resource_id: str, data: Dict[str, Any]) -> UniversalResource:
    """
    SY-2139 Protocol: Update Resource.
    فلترة صارمة بواسطة `owner=user` لضمان استحالة تعديل مورد يخص مستخدم آخر.
    """
    resource = UniversalResource.objects.get(id=resource_id, owner=user)
    resource.data = data
    
    resource.full_clean()
    resource.save()
    
    return resource

def delete_universal_resource(*, user: User, resource_id: str) -> None:
    """حذف المورد بآمان والتأكد من الصلاحية."""
    resource = UniversalResource.objects.get(id=resource_id, owner=user)
    resource.delete()