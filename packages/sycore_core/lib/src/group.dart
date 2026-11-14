/// SAMAM — a group with an epoch. Removing a member rotates the key, so a
/// removed member can read the past but never the future.
library;

import 'dart:typed_data';

import 'crypto.dart';
import 'envelope.dart';
import 'identity.dart';

class Group {
  Group({
    required this.id,
    required this.projectId,
    required this.domain,
    required this.epoch,
    required this.groupKey,
    required Map<String, Uint8List> members,
  }) : members = Map.of(members);

  final String id;
  final String projectId;
  final String domain;
  final int epoch;

  /// The content key for this epoch. Every message in the epoch is sealed with
  /// it, and it is wrapped once per member.
  final Uint8List groupKey;

  /// member id → X25519 public key.
  final Map<String, Uint8List> members;

  static Future<Group> create({
    required String id,
    required String projectId,
    required String domain,
    required List<Recipient> members,
    Uint8List? groupKey,
    int epoch = 1,
  }) async =>
      Group(
        id: id,
        projectId: projectId,
        domain: domain,
        epoch: epoch,
        groupKey: groupKey ?? randomBytes(32),
        members: {for (final m in members) m.id: m.dhPublic},
      );

  Future<Envelope> sealMessage({
    required String resourceId,
    required String ownerId,
    required Identity owner,
    required Uint8List vaultKey,
    required String plaintext,
  }) =>
      seal(
        projectId: projectId,
        domain: domain,
        resourceId: resourceId,
        ownerId: ownerId,
        vaultKey: vaultKey,
        owner: owner,
        plaintext: utf8b(plaintext),
        recipients: [
          for (final e in members.entries) Recipient(e.key, e.value),
        ],
        contentKey: groupKey,
      );

  /// Bump the epoch and generate a fresh key for the remaining members.
  ///
  /// This is the whole point of SAMAM: the removed member keeps the old key
  /// (and therefore the history they were entitled to) but cannot read
  /// anything sealed after the rotation.
  Group rotate({required Iterable<String> remaining}) {
    final next = <String, Uint8List>{};
    for (final id in remaining) {
      final pub = members[id];
      if (pub == null) throw StateError('not a member: $id');
      next[id] = pub;
    }
    return Group(
      id: id,
      projectId: projectId,
      domain: domain,
      epoch: epoch + 1,
      groupKey: randomBytes(32),
      members: next,
    );
  }
}
