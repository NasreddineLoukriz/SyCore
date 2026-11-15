/// SYCORE SDK — encrypted storage over a blind server.
///
/// ```dart
/// final sycore = SyCore(server: Uri.parse('http://127.0.0.1:8787'));
/// await sycore.register(userId: 'usr_ali', password: 'correct horse');
/// await sycore.hosn.send(
///   to: 'usr_sara', project: 'prj', domain: 'health', text: 'Surgery 8:30');
/// ```
library;

export 'package:sycore_core/sycore_core.dart'
    show Argon2Params, Envelope, Identity, Recipient, SycoreCryptoException,
        WrappedKey, aad, aeadOpen, aeadSeal, b64u, randomBytes, unb64u, utf8b;

export 'src/api.dart';
export 'src/local_store.dart';
export 'src/sycore.dart';
