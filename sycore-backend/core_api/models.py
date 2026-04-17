import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser

class SYCOREDomain(models.TextChoices):
    SAMAM = 'SAMAM', 'Business Management Domain'
    HOSN = 'HOSN', 'Sovereign Family Cloud (E2EE)'

class User(AbstractUser):
    """
    Custom User model using UUIDs as primary keys to support modern security
    standards across the SAMAM and HOSN domains.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    def __str__(self):
        return self.username

class UniversalResource(models.Model):
    """
    Generic Resource-Based Architecture central model.
    A single source of truth for diverse domains, no separate tables needed.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='resources')
    domain = models.CharField(max_length=10, choices=SYCOREDomain.choices)
    resource_type = models.CharField(max_length=100, db_index=True)
    
    # Core architectural pillar: All dynamic data goes here
    data = models.JSONField(default=dict)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.domain} | {self.resource_type} ({self.id})"

class UniversalAsset(models.Model):
    """
    Universal Storage model for file uploads. 
    HOSN domain payload is treated as E2EE blobs on the client side.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='assets')
    domain = models.CharField(max_length=10, choices=SYCOREDomain.choices)
    
    # Generic file tracking
    file = models.FileField(upload_to='assets/%Y/%m/%d/')
    mimetype = models.CharField(max_length=255)
    size = models.BigIntegerField()
    
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Asset for {self.domain} | {self.mimetype} ({self.id})"
