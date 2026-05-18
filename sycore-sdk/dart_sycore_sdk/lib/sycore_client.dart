import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
// الاستيراد الجديد لمكتبة الـ WebSockets
import 'package:web_socket_channel/web_socket_channel.dart';

import 'crypto/sycore_vault.dart';
import 'crypto/hosn_engine.dart';
import 'crypto/samam_engine.dart';
import 'crypto/jahr_engine.dart';
import 'network/graphql_client.dart';

class SycoreClient {
  final SycoreVault vault;
  final SycoreNetworkClient network;
  final HosnEngine hosn;
  final SamamEngine samam;
  final JahrEngine jahr;

  SycoreClient._({
    required this.vault,
    required this.network,
    required this.hosn,
    required this.samam,
    required this.jahr,
  });

  static Future<SycoreClient> initialize({
    required String endpointUrl,
    required String projectId,
  }) async {
    final network = SycoreNetworkClient(
      endpointUrl: endpointUrl, 
      projectId: projectId,
    );

    return SycoreClient._(
      vault: SycoreVault(),
      network: network,
      hosn: HosnEngine(),
      samam: SamamEngine(),
      jahr: JahrEngine(),
    );
  }

  // ==========================================
  // AUTH, VAULT & KEYS
  // ==========================================

  Future<void> signupAndSetupVault({
    required String username, 
    required String password, 
    String email = ''
  }) async {
    // 1. إنشاء الحساب في السيرفر
    final user = await network.signup(username, password, email: email);
    
    // 2. تسجيل الدخول للحصول على التوكن
    final token = await network.login(username, password);
    network.setToken(token);

    // 3. تهيئة المحفظة المحلية
    await vault.initializeVault(password, user['id']);

    // 4. توليد مفاتيح التشفير الأساسية
    final eccKeyPair = await vault.generateEccMessagingKeyPair();
    final edKeyPair = await vault.generateEd25519SignatureKeyPair();

    // 5. استخراج الـ Public Keys ورفعها لتصبح متاحة للاتصال
    final eccPublicKey = await eccKeyPair.extractPublicKey();
    final edPublicKey = await edKeyPair.extractPublicKey();

    await network.uploadPublicKey(
      eccPublicKey: base64Encode(eccPublicKey.bytes),
      ed25519PublicKey: base64Encode(edPublicKey.bytes),
    );
  }

  Future<void> login({required String password, required String token, required String userIdSalt}) async {
    await vault.initializeVault(password, userIdSalt);
    network.setToken(token);
  }

  Future<void> logout() async {
    await vault.lockVault();
    network.setToken('');
  }

  // ==========================================
  // HOSN (1-to-1 E2EE) - SEND & RECEIVE
  // ==========================================

  Future<Map<String, dynamic>?> sendHosnMessage({
    required String targetUserId, 
    required String domain,
    required String message,
  }) async {
    final senderVaultKey = await vault.getVaultKey();
    final senderEccKeyPair = await vault.generateEccMessagingKeyPair(); 
    
    final receiverData = await network.fetchUserPublicKey(targetUserId);
    final receiverPublicKey = SimplePublicKey(
      base64Decode(receiverData['eccPublicKey']), 
      type: KeyPairType.x25519
    );

    final payload = await hosn.encryptE2EEMessage(
      contentBytes: utf8.encode(message),
      senderKeyPair: senderEccKeyPair,
      senderVaultKey: senderVaultKey,
      receiverPublicKey: receiverPublicKey,
    );

    return await network.createResource(
      domain: domain,
      resourceType: 'Message',
      securityClearance: 'HOSN',
      data: payload,
    );
  }

  Future<List<String>> fetchAndDecryptHosnMessages({required String domain}) async {
    final resources = await network.fetchResources(domain: domain, resourceType: 'Message');
    final vaultKey = await vault.getVaultKey();
    final List<String> decryptedMessages = [];

    for (var res in resources) {
      try {
        final rawData = jsonDecode(res['data'] as String);
        
        // استخدام الدالة بالاسم الدقيق الموجود في محرك HOSN
        final decryptedBytes = await hosn.decryptE2EEResageBySender(
          payloadFromServer: rawData,
          senderVaultKey: vaultKey,
        );
        
        decryptedMessages.add(utf8.decode(decryptedBytes));
      } catch (e) {
        if (kDebugMode) {
          print("Failed to decrypt a HOSN message: $e");
        }
      }
    }
    return decryptedMessages;
  }

  // ==========================================
  // SAMAM (Team/Company Master Key) - SEND & RECEIVE
  // ==========================================

  Future<Map<String, dynamic>?> sendSamamMessage({
    required String domain,
    required String message,
    required SecretKey companyMasterKey,
  }) async {
    final payload = await samam.encryptContent(
      contentBytes: utf8.encode(message),
      companyMasterKey: companyMasterKey,
    );

    return await network.createResource(
      domain: domain,
      resourceType: 'TeamMessage',
      securityClearance: 'SAMAM',
      data: payload,
    );
  }

  Future<List<String>> fetchAndDecryptSamamMessages({
    required String domain,
    required SecretKey companyMasterKey,
  }) async {
    final resources = await network.fetchResources(domain: domain, resourceType: 'TeamMessage');
    final List<String> decryptedMessages = [];

    for (var res in resources) {
      try {
        final rawData = jsonDecode(res['data'] as String);
        final decryptedBytes = await samam.decryptContent(
          encryptedData: rawData, // <--- تم تغيير الاسم هنا من payload إلى encryptedData
          companyMasterKey: companyMasterKey, 
        );
        decryptedMessages.add(utf8.decode(decryptedBytes));
      } catch (e) {
        if (kDebugMode) {
          print("Failed to decrypt a SAMAM message: $e");
        }
      }
    }
    return decryptedMessages;
  }

  // ==========================================
  // JAHR (Public Signed Content)
  // ==========================================

  Future<Map<String, dynamic>?> publishJahrContent({
    required String domain,
    required String content,
  }) async {
     final senderSignatureKeyPair = await vault.generateEd25519SignatureKeyPair();

     final payload = await jahr.preparePublicContent(
       contentBytes: utf8.encode(content),
       senderKeyPair: senderSignatureKeyPair,
     );

     return await network.createResource(
      domain: domain,
      resourceType: 'PublicPost',
      securityClearance: 'JAHR',
      data: payload,
    );
  }

  // ==========================================
  // REAL-TIME (WebSockets)
  // ==========================================

  Stream<Map<String, dynamic>> listenToDomain(String domain) {
    // نتأكد أولاً من وجود توكن صالح للاتصال
    if (network.token.isEmpty) {
      throw Exception('Authentication required for real-time connection. Please login first.');
    }
    
    // استبدال _authToken بـ network.token
    final wsUrl = network.endpointUrl.replaceFirst('http', 'ws');
    final channel = WebSocketChannel.connect(
      Uri.parse('$wsUrl/ws/realtime/?token=${network.token}')
    );

    // يفلتر الأحداث التي تخص الدومين المطلوب فقط
    return channel.stream
        .map((event) => jsonDecode(event as String) as Map<String, dynamic>)
        .where((data) => data['domain'] == domain);
  }
}