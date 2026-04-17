from typing import Dict, Any
from core_api.models import UniversalResource, User
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

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

def delete_universal_resource(*, user: User, resource_id: str) -> None:
    resource = UniversalResource.objects.get(id=resource_id, owner=user)
    resource_id_str = str(resource.id)
    resource.delete()
    
    notify_user_realtime(user.id, 'resource.deleted', {
        'id': resource_id_str
    })