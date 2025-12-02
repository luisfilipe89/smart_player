import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';

class EmailServiceInstance {
  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  EmailServiceInstance(this._db, this._auth);

  /// Send a friend invite email using a Firebase-triggered email mechanism.
  /// This writes to the `mail` collection in Realtime Database which should be
  /// picked up by the Firebase Email extension (or a custom backend listener).
  Future<bool> sendFriendInviteEmail({
    required String recipientEmail,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final String inviterName =
          user.displayName ?? _deriveNameFromEmail(user.email) ?? 'User';
      final String inviterEmail = user.email ?? '';
      final String recipientName = _deriveNameFromEmail(recipientEmail) ?? '';
      final String inviteLink =
          'https://smartplayer.app/invite?email=${Uri.encodeComponent(recipientEmail)}';

      // Generate unique email ID
      final String emailId = const Uuid().v4();

      final htmlBody = _generateInviteEmailHtml(
        inviterName: inviterName,
        inviterEmail: inviterEmail,
        recipientName: recipientName,
        inviteLink: inviteLink,
      );
      final textBody = _generateInviteEmailText(
        inviterName: inviterName,
        inviterEmail: inviterEmail,
        recipientName: recipientName,
        inviteLink: inviteLink,
      );

      // Payload stored in Realtime Database (legacy pipeline / audit)
      final Map<String, dynamic> realtimeEmailData = {
        'to': recipientEmail,
        'message': {
          'subject': 'friends_invite_email_title'.tr(),
          'html': htmlBody,
          'text': textBody,
        },
        'template': {
          'name': 'friend_invite',
          'data': {
            'inviterName': inviterName,
            'inviterEmail': inviterEmail,
            'recipientName': recipientName,
            'appName': 'SMARTPLAYER',
            'inviteLink': inviteLink,
          },
        },
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      };

      if (inviterEmail.isNotEmpty) {
        realtimeEmailData['replyTo'] = inviterEmail;
      }

      // Write to mail collection to trigger email extension
      await _db.ref('${DbPaths.mail}/$emailId').set(realtimeEmailData);

      // Mirror into Firestore for the Trigger Email extension
      final firestoreEmailData = {
        'to': [recipientEmail],
        'message': {
          'subject': 'friends_invite_email_title'.tr(),
          'html': htmlBody,
          'text': textBody,
        },
        'template': {
          'name': 'friend_invite',
          'data': {
            'inviterName': inviterName,
            'inviterEmail': inviterEmail,
            'recipientName': recipientName,
            'appName': 'SMARTPLAYER',
            'inviteLink': inviteLink,
          },
        },
        'createdAt': Timestamp.now(),
        'status': 'pending',
        'fromUid': user.uid,
      };

      if (inviterEmail.isNotEmpty) {
        firestoreEmailData['replyTo'] = inviterEmail;
      }

      await FirebaseFirestore.instance
          .collection(DbPaths.mail)
          .doc(emailId)
          .set(firestoreEmailData);

      // Store a lightweight rate-limit record
      await _db.ref('${DbPaths.emailInvites}/$emailId').set({
        'fromUid': user.uid,
        'toEmail': recipientEmail,
        'createdAt': ServerValue.timestamp,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if an invite to [email] can be sent now.
  /// Rate limiting has been disabled, so this always returns true when the user is authenticated.
  Future<bool> canSendInviteToEmail(String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      return true;
    } catch (e) {
      return true; // Allow on error to avoid blocking due to transient failures
    }
  }

  String? _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    final String prefix = email.split('@').first;
    final String cleaned = prefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (cleaned.isEmpty) return prefix;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String _generateInviteEmailHtml({
    required String inviterName,
    required String inviterEmail,
    required String recipientName,
    required String inviteLink,
  }) {
    return 'friends_invite_email_html'.tr(namedArgs: {
      'recipientName': recipientName,
      'inviterName': inviterName,
      'inviterEmail': inviterEmail,
      'inviteLink': inviteLink,
    });
  }

  String _generateInviteEmailText({
    required String inviterName,
    required String inviterEmail,
    required String recipientName,
    required String inviteLink,
  }) {
    return 'friends_invite_email_text'.tr(namedArgs: {
      'recipientName': recipientName,
      'inviterName': inviterName,
      'inviterEmail': inviterEmail,
      'inviteLink': inviteLink,
    });
  }
}
