import graphene
import graphql_jwt
from graphene_django import DjangoObjectType
from core_api.models import UniversalResource
from core_api.selectors import get_user_resources
from core_api.services import create_universal_resource, update_universal_resource

class UniversalResourceType(DjangoObjectType):
    class Meta:
        model = UniversalResource
        fields = ('id', 'domain', 'resource_type', 'data', 'created_at', 'updated_at')

class Query(graphene.ObjectType):
    user_resources = graphene.List(
        UniversalResourceType,
        domain=graphene.String(required=False),
        resource_type=graphene.String(required=False)
    )

    def resolve_user_resources(self, info, domain=None, resource_type=None):
        user = info.context.user
        if not user.is_authenticated:
            return UniversalResource.objects.none()
        return get_user_resources(user=user, domain=domain, resource_type=resource_type)

class CreateResourceMutation(graphene.Mutation):
    class Arguments:
        domain = graphene.String(required=True)
        resource_type = graphene.String(required=True)
        data = graphene.JSONString(required=True)

    resource = graphene.Field(UniversalResourceType)

    def mutate(self, info, domain, resource_type, data):
        user = info.context.user
        if not user.is_authenticated:
            raise Exception("Authentication required")
        resource = create_universal_resource(
            user=user,
            domain=domain,
            resource_type=resource_type,
            data=data
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

class Mutation(graphene.ObjectType):
    # SY-2139 Protocol: Token-based Authentication
    token_auth = graphql_jwt.ObtainJSONWebToken.Field()
    verify_token = graphql_jwt.Verify.Field()
    refresh_token = graphql_jwt.Refresh.Field()
    
    create_resource = CreateResourceMutation.Field()
    update_resource = UpdateResourceMutation.Field()

schema = graphene.Schema(query=Query, mutation=Mutation)
