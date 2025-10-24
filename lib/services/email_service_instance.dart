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

      // Generate unique email ID
      final String emailId = const Uuid().v4();

      // Create email document for Firebase Trigger Email extension
      final Map<String, dynamic> emailData = {
        'to': recipientEmail,
        'message': {
          'subject': 'friends_invite_email_title'.tr(),
          'html': _generateInviteEmailHtml(
            inviterName: inviterName,
            inviterEmail: inviterEmail,
            recipientName: recipientName,
          ),
          'text': _generateInviteEmailText(
            inviterName: inviterName,
            inviterEmail: inviterEmail,
            recipientName: recipientName,
          ),
        },
        'template': {
          'name': 'friend_invite',
          'data': {
            'inviterName': inviterName,
            'inviterEmail': inviterEmail,
            'recipientName': recipientName,
            'appName': 'SMARTPLAYER',
            'inviteLink':
                'https://smartplayer.app/invite?email=${Uri.encodeComponent(recipientEmail)}',
          },
        },
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      };

      // Write to mail collection to trigger email extension
      await _db.ref('${DbPaths.mail}/$emailId').set(emailData);

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

  /// Check if an invite to [email] can be sent now (simple rate limiting).
  /// Allows one invite per hour per recipient from the same sender.
  Future<bool> canSendInviteToEmail(String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final oneHourAgo = now - (60 * 60 * 1000);

      // Simplified query to avoid requiring an index on `fromUid`.
      // Fetch all invites and filter client-side by `fromUid`, `toEmail`, and time window.
      final invitesRef = _db.ref(DbPaths.emailInvites);
      final snapshot = await invitesRef.get();

      if (snapshot.exists) {
        final Map data = snapshot.value as Map;
        for (final invite in data.values) {
          if (invite is Map) {
            final fromUid = invite['fromUid']?.toString() ?? '';
            final inviteEmail = invite['toEmail']?.toString() ?? '';
            final inviteTime = invite['createdAt'] as int? ?? 0;
            if (fromUid == user.uid &&
                inviteEmail.toLowerCase() == email.toLowerCase() &&
                inviteTime > oneHourAgo) {
              return false;
            }
          }
        }
      }

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
  }) {
    return 'friends_invite_email_html'
        .tr(args: [recipientName, inviterName, inviterEmail]);
  }

  String _generateInviteEmailText({
    required String inviterName,
    required String inviterEmail,
    required String recipientName,
  }) {
    return 'friends_invite_email_text'
        .tr(args: [recipientName, inviterName, inviterEmail]);
  }
}
