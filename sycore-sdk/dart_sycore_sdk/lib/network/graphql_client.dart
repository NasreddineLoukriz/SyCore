// lib/network/graphql_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:graphql_flutter/graphql_flutter.dart';

class SycoreNetworkClient {
  final String endpointUrl;
  final String projectId;
  String? _jwtToken;
  late GraphQLClient _client;

  SycoreNetworkClient({required this.endpointUrl, required this.projectId}) {
    _initClient();
  }

  void setToken(String token) {
    _jwtToken = token;
    _initClient(); 
  }

  String get token => _jwtToken ?? '';

  void _initClient() {
    final HttpLink httpLink = HttpLink(
      endpointUrl,
      defaultHeaders: {
        'X-Sycore-Project-Id': projectId,
        if (_jwtToken != null && _jwtToken!.isNotEmpty) 
          'Authorization': 'Bearer $_jwtToken',
      },
    );

    _client = GraphQLClient(
      cache: GraphQLCache(),
      link: httpLink,
    );
  }

  // ==========================================
  // AUTHENTICATION & USERS
  // ==========================================

  Future<String> login(String username, String password) async {
    const String mutation = r'''
      mutation TokenAuth($username: String!, $password: String!) {
        tokenAuth(username: $username, password: $password) {
          token
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'username': username, 'password': password},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Login failed: ${result.exception.toString()}');
    return result.data!['tokenAuth']['token'];
  }

  Future<Map<String, dynamic>> signup(String username, String password, {String email = ''}) async {
    const String mutation = r'''
      mutation Signup($username: String!, $password: String!, $email: String) {
        signup(username: $username, password: $password, email: $email) {
          user {
            id
            username
            email
          }
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'username': username, 'password': password, 'email': email},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Signup failed: ${result.exception.toString()}');
    return result.data!['signup']['user'];
  }

  // ==========================================
  // PUBLIC KEYS
  // ==========================================

  Future<bool> uploadPublicKey({required String eccPublicKey, String? ed25519PublicKey}) async {
    const String mutation = r'''
      mutation UploadPublicKey($eccPublicKey: String!, $ed25519PublicKey: String) {
        uploadPublicKey(eccPublicKey: $eccPublicKey, ed25519PublicKey: $ed25519PublicKey) {
          success
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'eccPublicKey': eccPublicKey, 'ed25519PublicKey': ed25519PublicKey},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Failed to upload public keys: ${result.exception.toString()}');
    return result.data!['uploadPublicKey']['success'];
  }

  Future<Map<String, dynamic>> fetchUserPublicKey(String userId) async {
    const String query = r'''
      query GetUserPublicKey($userId: ID!) {
        userPublicKey(userId: $userId) {
          eccPublicKey
          ed25519PublicKey
        }
      }
    ''';
    final options = QueryOptions(
      document: gql(query),
      variables: {'userId': userId},
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(options);
    if (result.hasException) throw Exception('Failed to fetch public key: ${result.exception.toString()}');
    return result.data!['userPublicKey'];
  }

  // ==========================================
  // RESOURCES (HOSN, SAMAM, JAHR)
  // ==========================================

  Future<Map<String, dynamic>> createResource({
    required String domain,
    required String resourceType,
    required String securityClearance,
    required Map<String, dynamic> data,
  }) async {
    const String mutation = r'''
      mutation CreateResource($domain: String!, $resourceType: String!, $securityClearance: String!, $data: JSONString!) {
        createResource(
          domain: $domain
          resourceType: $resourceType
          securityClearance: $securityClearance
          data: $data
        ) {
          resource {
            id
            createdAt
          }
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {
        'domain': domain,
        'resourceType': resourceType,
        'securityClearance': securityClearance,
        'data': jsonEncode(data),
      },
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Failed to create resource: ${result.exception.toString()}');
    return result.data!['createResource']['resource'];
  }

  Future<Map<String, dynamic>> updateResource(String id, Map<String, dynamic> data) async {
    const String mutation = r'''
      mutation UpdateResource($id: ID!, $data: JSONString!) {
        updateResource(id: $id, data: $data) {
          resource {
            id
            updatedAt
          }
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id, 'data': jsonEncode(data)},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Failed to update resource: ${result.exception.toString()}');
    return result.data!['updateResource']['resource'];
  }

  Future<List<dynamic>> fetchResources({String? domain, String? resourceType, int? limit, int? offset}) async {
    const String query = r'''
      query GetUserResources($domain: String, $resourceType: String, $limit: Int, $offset: Int) {
        userResources(domain: $domain, resourceType: $resourceType, limit: $limit, offset: $offset) {
          id
          domain
          resourceType
          data
          createdAt
        }
      }
    ''';
    final options = QueryOptions(
      document: gql(query),
      variables: {'domain': domain, 'resourceType': resourceType, 'limit': limit, 'offset': offset},
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(options);
    if (result.hasException) throw Exception('Failed to fetch resources: ${result.exception.toString()}');
    return result.data!['userResources'];
  }

  Future<Map<String, dynamic>> fetchResourceById(String id) async {
    const String query = r'''
      query GetResourceById($id: ID!) {
        resourceById(id: $id) {
          id
          domain
          resourceType
          data
          createdAt
        }
      }
    ''';
    final options = QueryOptions(
      document: gql(query),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(options);
    if (result.hasException) throw Exception('Failed to fetch resource: ${result.exception.toString()}');
    return result.data!['resourceById'];
  }

  Future<bool> deleteResource(String id) async {
    const String mutation = r'''
      mutation DeleteResource($id: ID!) {
        deleteResource(id: $id) {
          success
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Failed to delete resource: ${result.exception.toString()}');
    return result.data!['deleteResource']['success'];
  }

  // ==========================================
  // ASSETS (FILES)
  // ==========================================

  Future<Map<String, dynamic>> uploadAsset({required String domain, required http.MultipartFile file}) async {
    const String mutation = r'''
      mutation UploadAsset($domain: String!, $file: Upload!) {
        uploadAsset(domain: $domain, file: $file) {
          asset {
            id
            fileUrl
            mimetype
            size
          }
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'domain': domain, 'file': file},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Failed to upload asset: ${result.exception.toString()}');
    return result.data!['uploadAsset']['asset'];
  }

  Future<bool> deleteAsset(String id) async {
    const String mutation = r'''
      mutation DeleteAsset($id: ID!) {
        deleteAsset(id: $id) {
          success
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Failed to delete asset: ${result.exception.toString()}');
    return result.data!['deleteAsset']['success'];
  }

  Future<Map<String, dynamic>> updateAsset(String id, {String? domain, http.MultipartFile? file}) async {
    const String mutation = r'''
      mutation UpdateAsset($id: ID!, $domain: String, $file: Upload) {
        updateAsset(id: $id, domain: $domain, file: $file) {
          asset {
            id
            domain
            fileUrl
          }
        }
      }
    ''';
    final options = MutationOptions(
      document: gql(mutation),
      variables: {'id': id, 'domain': domain, 'file': file},
    );
    final result = await _client.mutate(options);
    if (result.hasException) throw Exception('Failed to update asset: ${result.exception.toString()}');
    return result.data!['updateAsset']['asset'];
  }

  Future<Map<String, dynamic>> fetchAssetById(String id) async {
    const String query = r'''
      query GetAssetById($id: ID!) {
        assetById(id: $id) {
          id
          domain
          fileUrl
          mimetype
          size
          createdAt
        }
      }
    ''';
    final options = QueryOptions(
      document: gql(query),
      variables: {'id': id},
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(options);
    if (result.hasException) throw Exception('Failed to fetch asset: ${result.exception.toString()}');
    return result.data!['assetById'];
  }

  Future<List<dynamic>> fetchUserAssets({String? domain, int? limit, int? offset}) async {
    const String query = r'''
      query GetUserAssets($domain: String, $limit: Int, $offset: Int) {
        userAssets(domain: $domain, limit: $limit, offset: $offset) {
          id
          fileUrl
          mimetype
          size
          createdAt
        }
      }
    ''';
    final options = QueryOptions(
      document: gql(query),
      variables: {'domain': domain, 'limit': limit, 'offset': offset},
      fetchPolicy: FetchPolicy.networkOnly,
    );
    final result = await _client.query(options);
    if (result.hasException) throw Exception('Failed to fetch assets: ${result.exception.toString()}');
    return result.data!['userAssets'];
  }
}