from urllib.parse import parse_qs
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser
from asgiref.sync import sync_to_async
from django.conf import settings
from jwt import decode, ExpiredSignatureError, InvalidTokenError
from core_api.models import User

@sync_to_async
def get_user_from_jwt(token):
    try:
        decoded_data = decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        # لقد غيرنا البحث ليستخدم username بناءً على صيغة graphene-jwt
        username = decoded_data.get("username")
        return User.objects.get(username=username) if username else AnonymousUser()
    except (ExpiredSignatureError, InvalidTokenError, User.DoesNotExist, Exception) as e:
        print(f"\n[🔴 SY-2139 ERROR] سبب رفض الاتصال: {str(e)}\n")
        return AnonymousUser()

class TokenAuthMiddleware(BaseMiddleware):
    """
    SY-2139 Protocol: Authenticates WebSocket connections using JWT tokens
    passed typically via query parameters: `ws://..?token=<jwt>`
    """
    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode('utf-8')
        query_params = parse_qs(query_string)

        token_list = query_params.get('token', [])
        if token_list:
            token = token_list[0]
            scope['user'] = await get_user_from_jwt(token)
        else:
            scope['user'] = AnonymousUser()

        return await super().__call__(scope, receive, send)
