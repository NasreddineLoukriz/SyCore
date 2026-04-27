import json
from channels.generic.websocket import AsyncWebsocketConsumer

class SY2139Consumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get('user', None)

        # Allow only authenticated users
        if not self.user or self.user.is_anonymous:
            await self.close()
            return

        # SY-2139 Zero-Knowledge Privacy: Isolate WebSocket Group strictly per user
        self.group_name = f'user_{self.user.id}'
        
        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name
        )

        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(
                self.group_name,
                self.channel_name
            )

    async def receive(self, text_data=None, bytes_data=None):
        """
        By default, clients don't need to send messages to the server.
        The server pushes updates (Real-Time Synergy).
        """
        pass

    async def resource_event(self, event):
        """
        Invoked from services.py via channel_layer.group_send
        """
        payload = event.get('payload', {})
        message_json = json.dumps(payload)
        await self.send(text_data=message_json)
