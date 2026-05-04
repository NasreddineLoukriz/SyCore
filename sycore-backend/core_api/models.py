import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    """
    Custom User model using UUIDs as primary keys to support modern security
    standards across the SAMAM and HOSN domains.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    # --- SY-2139 Limits ---
    is_upload_banned = models.BooleanField(default=False)
    max_upload_size_mb = models.IntegerField(default=10)
    max_total_assets = models.IntegerField(default=100)

    def __str__(self):
        return self.username

class UserPublicKey(models.Model):
    """
    جدول لحفظ المفاتيح العامة (Public Keys) للمستخدمين بغرض بروتوكول SY-2139.
    يتم تخزينها بتشفير Base64.
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='public_key')
    ecc_public_key = models.TextField(help_text="المفتاح العام للتبادل ECC (HOSN/SAMAM)")
    ed25519_public_key = models.TextField(help_text="المفتاح العام للتوقيع (JAHR) - اختياري", null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Public Keys for {self.user.username}"

class DomainPolicy(models.Model):
    """
    Policy Immutability Gate (Trust on First Use).
    Locks a domain to a specific security clearance for a given project_id.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project_id = models.CharField(max_length=50, db_index=True)
    name = models.CharField(max_length=50, db_index=True)
    
    # الحقل أصبح نصياً حراً لتلبية التطور الديناميكي المستقبلي للـ SDK
    security_clearance = models.CharField(max_length=100) 
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('project_id', 'name')

    def __str__(self):
        return f"[{self.project_id}] {self.name} -> {self.security_clearance}"

class UniversalResource(models.Model):
    """
    Generic Resource-Based Architecture central model.
    A single source of truth for diverse domains, no separate tables needed.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project_id = models.CharField(max_length=50, db_index=True, default="default")
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='resources')
    domain = models.CharField(max_length=50, db_index=True)
    resource_type = models.CharField(max_length=100, db_index=True)
    
    # Core architectural pillar: All dynamic data goes here
    data = models.JSONField(default=dict)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"[{self.project_id}] {self.domain} | {self.resource_type} ({self.id})"

class UniversalAsset(models.Model):
    """
    Universal Storage model for file uploads. 
    HOSN domain payload is treated as E2EE blobs on the client side.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    project_id = models.CharField(max_length=50, db_index=True, default="default")
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='assets')
    domain = models.CharField(max_length=50, db_index=True)
    
    # Generic file tracking
    file = models.FileField(upload_to='assets/%Y/%m/%d/')
    mimetype = models.CharField(max_length=255)
    size = models.BigIntegerField()
    
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Asset for [{self.project_id}] {self.domain} | {self.mimetype} ({self.id})"
