import graphene
import graphql_jwt
from graphene_django import DjangoObjectType
from graphene_file_upload.scalars import Upload
from core_api.models import UniversalResource, UniversalAsset, User, UserPublicKey
from core_api.selectors import get_user_resources, get_user_assets, get_resource_by_id, get_asset_by_id
from core_api.services import (create_universal_resource, update_universal_resource, 
                               upload_universal_asset, create_user, admin_manage_user,
                               delete_universal_resource, delete_universal_asset,
                               update_universal_asset)

class UniversalAssetType(DjangoObjectType):
    class Meta:
        model = UniversalAsset
        fields = ('id', 'domain', 'file', 'mimetype', 'size', 'created_at')

    file_url = graphene.String()

    def resolve_file_url(self, info):
        if self.file and hasattr(self.file, 'url'):
            request = info.context
            return request.build_absolute_uri(self.file.url)
        return None

class UniversalResourceType(DjangoObjectType):
    class Meta:
        model = UniversalResource
        fields = ('id', 'domain', 'resource_type', 'data', 'created_at', 'updated_at')

class UserType(DjangoObjectType):
    class Meta:
        model = User
        fields = (
            'id', 'username', 'email', 
            'is_active', 'is_staff', 'is_superuser',
            'is_upload_banned', 'max_upload_size_mb', 'max_total_assets'
        )

class UserPublicKeyType(DjangoObjectType):
    class Meta:
        model = UserPublicKey
        fields = ('ecc_public_key', 'ed25519_public_key', 'updated_at')

class Query(graphene.ObjectType):
    # قائمة المستخدمين مع Pagination
    all_users = graphene.List(
        UserType,
        limit=graphene.Int(required=False),
        offset=graphene.Int(required=False)
    )
    
    # موارد المستخدم مع Pagination
    user_resources = graphene.List(
        UniversalResourceType,
        domain=graphene.String(required=False),
        resource_type=graphene.String(required=False),
        # إضافة وسيط التاريخ هنا
        updated_since=graphene.DateTime(required=False), 
        limit=graphene.Int(required=False),
        offset=graphene.Int(required=False)
    )
    
    # ملفات المستخدم مع Pagination
    user_assets = graphene.List(
        UniversalAssetType,
        domain=graphene.String(required=False),
        limit=graphene.Int(required=False),
        offset=graphene.Int(required=False)
    )

    # -------- [الإضافات الجديدة: جلب عنصر واحد] --------
    resource_by_id = graphene.Field(
        UniversalResourceType, 
        id=graphene.ID(required=True)
    )
    asset_by_id = graphene.Field(
        UniversalAssetType, 
        id=graphene.ID(required=True)
    )

    # دالة جلب مورد واحد
    def resolve_resource_by_id(self, info, id):
        user = info.context.user
        project_id = getattr(info.context, 'project_id', None)
        
        if not project_id:
            raise Exception("Project ID is required")
        
        # جلب المورد أولاً للتحقق من نوعه قبل رفض الطلب
        resource = get_resource_by_id(user if user.is_authenticated else None, project_id, id)
        
        # إذا كان المورد ينتمي لدومين سياسته JAHR، نسمح للجميع بقراءته
        # نفترض هنا أن إما تمرر security_clearance مع المورد أو DomainPolicy
        # هنا طريقة سريعة: إذا لم يكن مسجلاً، تأكد أن سياسته عامة
        from core_api.models import DomainPolicy
        try:
            policy = DomainPolicy.objects.get(project_id=project_id, name=resource.domain)
            if policy.security_clearance != 'JAHR' and not user.is_authenticated:
                raise Exception("Authentication required for non-JAHR resources")
        except DomainPolicy.DoesNotExist:
            if not user.is_authenticated:
                 raise Exception("Authentication required")

        return resource

    # دالة جلب ملف واحد
    def resolve_asset_by_id(self, info, id):
        user = info.context.user
        project_id = getattr(info.context, 'project_id', None)
        
        if not user.is_authenticated or not project_id:
            raise Exception("Authentication and Project ID are required")
            
        return get_asset_by_id(user, project_id, id)
    
    # دالة جلب موارد المستخدم مع Pagination
    def resolve_user_resources(self, info, domain=None, resource_type=None, updated_since=None, limit=None, offset=None):
        user = info.context.user
        project_id = getattr(info.context, 'project_id', None)
        
        if not project_id:
            raise Exception("Project ID is required")
            
        # التحقق من سياسة الدومين إذا تم تمريره
        is_jahr_request = False
        from core_api.models import DomainPolicy
        if domain:
            policy = DomainPolicy.objects.filter(project_id=project_id, name=domain).first()
            if policy and policy.security_clearance == 'JAHR':
                is_jahr_request = True

        # إذا لم يكن مسجلاً وليس طلب JAHR نرفض!
        if not user.is_authenticated and not is_jahr_request:
            return UniversalResource.objects.none()
            
        # إذا كان الطلب JAHR نجلب الموارد لهذا الدومين بغض النظر عن المالك
        if is_jahr_request:
             qs = UniversalResource.objects.filter(project_id=project_id, domain=domain)
        else:
             qs = get_user_resources(
                user=user, 
                project_id=project_id,
                domain=domain, 
                resource_type=resource_type, 
             )
        
        if updated_since:
            qs = qs.filter(updated_at__gte=updated_since)
            
        if offset is not None:
            qs = qs[offset:]
        if limit is not None:
            qs = qs[:limit]
            
        return qs

    # دالة جلب ملفات المستخدم مع Pagination
    def resolve_user_assets(self, info, domain=None, limit=None, offset=None):
        user = info.context.user
        project_id = getattr(info.context, 'project_id', None)
        
        if not user.is_authenticated or not project_id:
            return UniversalAsset.objects.none()
        
        qs = UniversalAsset.objects.filter(owner=user).order_by('-created_at')
        if domain:
            qs = qs.filter(domain=domain)
            
        # تطبيق التقسيم (Pagination)
        if offset is not None:
            qs = qs[offset:]
        if limit is not None:
            qs = qs[:limit]
            
        return qs

    user_public_key = graphene.Field(
        UserPublicKeyType, 
        user_id=graphene.ID(required=True)
    )

    def resolve_user_public_key(self, info, user_id):
        # السماح لأي شخص مسجل بالبحث عن المفتاح العام للآخرين
        if not info.context.user.is_authenticated:
            raise Exception("Authentication required")
        try:
            return UserPublicKey.objects.get(user_id=user_id)
        except UserPublicKey.DoesNotExist:
            raise Exception("Public key not found for this user")

class CreateResourceMutation(graphene.Mutation):
    class Arguments:
        domain = graphene.String(required=True)
        resource_type = graphene.String(required=True)
        data = graphene.JSONString(required=True)
        security_clearance = graphene.String(required=True) # إضافة نوع التشفير

    resource = graphene.Field(UniversalResourceType)

    def mutate(self, info, domain, resource_type, data, security_clearance):
        user = info.context.user
        project_id = getattr(info.context, 'project_id', None)
        
        if not user.is_authenticated or not project_id:
            raise Exception("Authentication and Project ID required")
            
        resource = create_universal_resource(
            user=user,
            project_id=project_id,
            domain=domain,
            resource_type=resource_type,
            data=data,
            security_clearance=security_clearance
        )
        return CreateResourceMutation(resource=resource)

class UpdateResourceMutation(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)
        data = graphene.JSONString(required=True)

    resource = graphene.Field(UniversalResourceType)

    def mutate(self, info, id, data):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")
        resource = update_universal_resource(
            resource_id=id,
            user=user,
            data=data
        )
        return UpdateResourceMutation(resource=resource)

class UploadAssetMutation(graphene.Mutation):
    class Arguments:
        domain = graphene.String(required=True)
        file = Upload(required=True)

    asset = graphene.Field(UniversalAssetType)

    def mutate(self, info, domain, file):
        user = info.context.user
        project_id = getattr(info.context, 'project_id', None)
        
        if not user.is_authenticated or not project_id:
            raise Exception("Authentication and Project ID required")
            
        asset = upload_universal_asset(
            user=user,
            project_id=project_id,
            file_obj=file
        )
        return UploadAssetMutation(asset=asset)

class UpdateAssetMutation(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)
        domain = graphene.String(required=False)
        # الملف اختياري، بحيث يمكن تعديل النطاق (أو الوصف لاحقاً) دون رفع الملف مجدداً
        file = Upload(required=False)

    asset = graphene.Field(UniversalAssetType)

    def mutate(self, info, id, domain=None, file=None):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")
            
        asset = update_universal_asset(
            user=user,
            asset_id=id,
            domain=domain,
            file_obj=file
        )
        return UpdateAssetMutation(asset=asset)

class SignupMutation(graphene.Mutation):
    class Arguments:
        username = graphene.String(required=True)
        password = graphene.String(required=True)
        email = graphene.String(required=False)

    user = graphene.Field(UserType)

    def mutate(self, info, username, password, email=''):
        user = create_user(username=username, password=password, email=email)
        return SignupMutation(user=user)

class AdminManageUserMutation(graphene.Mutation):
    """
    Mutation كامل لإدارة مستخدم من قبل لوحة التحكم (sycore-console).
    """
    class Arguments:
        target_user_id = graphene.ID(required=True)
        username = graphene.String(required=False)
        email = graphene.String(required=False)
        password = graphene.String(required=False)
        # صلاحيات إدارة Django
        is_active = graphene.Boolean(required=False)
        is_staff = graphene.Boolean(required=False)
        is_superuser = graphene.Boolean(required=False)
        # صلاحيات بروتوكول SY-2139 Limits
        is_upload_banned = graphene.Boolean(required=False)
        max_upload_size_mb = graphene.Int(required=False)
        max_total_assets = graphene.Int(required=False)

    user = graphene.Field(UserType)

    def mutate(self, info, target_user_id, **kwargs):
        admin_user = info.context.user
        
        # التأكد أن المستخدم مسجل الدخول
        if not admin_user.is_authenticated:
            raise Exception("Authentication required")
            
        # تنفيذ التعديل عبر دالة الخدمة
        updated_user = admin_manage_user(
            admin_user=admin_user,
            target_user_id=target_user_id,
            username=kwargs.get('username'),
            email=kwargs.get('email'),
            password=kwargs.get('password'),
            is_active=kwargs.get('is_active'),
            is_staff=kwargs.get('is_staff'),
            is_superuser=kwargs.get('is_superuser'),
            is_upload_banned=kwargs.get('is_upload_banned'),
            max_upload_size_mb=kwargs.get('max_upload_size_mb'),
            max_total_assets=kwargs.get('max_total_assets')
        )
        return AdminManageUserMutation(user=updated_user)

class DeleteResourceMutation(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)

    success = graphene.Boolean()

    def mutate(self, info, id):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")
            
        success = delete_universal_resource(user=user, resource_id=id)
        return DeleteResourceMutation(success=success)

class DeleteAssetMutation(graphene.Mutation):
    class Arguments:
        id = graphene.ID(required=True)

    success = graphene.Boolean()

    def mutate(self, info, id):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")
            
        success = delete_universal_asset(user=user, asset_id=id)
        return DeleteAssetMutation(success=success)

class UploadPublicKeyMutation(graphene.Mutation):
    class Arguments:
        ecc_public_key = graphene.String(required=True)
        ed25519_public_key = graphene.String(required=False)

    success = graphene.Boolean()

    def mutate(self, info, ecc_public_key, ed25519_public_key=None):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")
            
        # تحديث أو إنشاء المفتاح
        UserPublicKey.objects.update_or_create(
            user=user,
            defaults={
                'ecc_public_key': ecc_public_key,
                'ed25519_public_key': ed25519_public_key
            }
        )
        return UploadPublicKeyMutation(success=True)

class Mutation(graphene.ObjectType):
    # SY-2139 Protocol: Token-based Authentication
    token_auth = graphql_jwt.ObtainJSONWebToken.Field()
    verify_token = graphql_jwt.Verify.Field()
    refresh_token = graphql_jwt.Refresh.Field()
    
    create_resource = CreateResourceMutation.Field()
    update_resource = UpdateResourceMutation.Field()
    upload_asset = UploadAssetMutation.Field()
    signup = SignupMutation.Field()
    admin_manage_user = AdminManageUserMutation.Field()
    delete_resource = DeleteResourceMutation.Field()
    delete_asset = DeleteAssetMutation.Field()
    update_asset = UpdateAssetMutation.Field()
    
    # 👈 الإضافة الخاصة برفع المفاتيح العامة للسيرفر
    upload_public_key = UploadPublicKeyMutation.Field()

schema = graphene.Schema(query=Query, mutation=Mutation)
