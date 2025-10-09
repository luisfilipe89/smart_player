import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

class EmailService {
  static FirebaseDatabase get _db => FirebaseDatabase.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Send a friend invite email using a Firebase-triggered email mechanism.
  /// This writes to the `mail` collection in Realtime Database which should be
  /// picked up by the Firebase Email extension (or a custom backend listener).
  static Future<bool> sendFriendInviteEmail({
    required String recipientEmail,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final String inviterName =
          user.displayName ?? _deriveNameFromEmail(user.email) ?? 'Someone';
      final String inviterEmail = user.email ?? '';
      final String recipientName = _deriveNameFromEmail(recipientEmail) ?? '';

      // Generate unique email ID
      final String emailId = const Uuid().v4();

      // Create email document for Firebase Trigger Email extension
      final Map<String, dynamic> emailData = {
        'to': recipientEmail,
        'message': {
          'subject': 'Join me on SMARTPLAYER!',
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
      await _db.ref('mail/$emailId').set(emailData);

      // Store a lightweight rate-limit record
      await _db.ref('emailInvites/$emailId').set({
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
  static Future<bool> canSendInviteToEmail(String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final oneHourAgo = now - (60 * 60 * 1000);

      // Simplified query to avoid requiring an index on `fromUid`.
      // Fetch all invites and filter client-side by `fromUid`, `toEmail`, and time window.
      final invitesRef = _db.ref('emailInvites');
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

  static String? _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    final String prefix = email.split('@').first;
    final String cleaned = prefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (cleaned.isEmpty) return prefix;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  static String _generateInviteEmailHtml({
    required String inviterName,
    required String inviterEmail,
    required String recipientName,
  }) {
    return '''
<!DOCTYPE html>
<html>
  <body>
    <p>Hi $recipientName,</p>
    <p>$inviterName ($inviterEmail) invited you to join SMARTPLAYER.</p>
    <p><a href="https://smartplayer.app">Create your account</a> and connect as friends!</p>
    <p>If you don't want to receive these emails, you can ignore this message.</p>
  </body>
  </html>
''';
  }

  static String _generateInviteEmailText({
    required String inviterName,
    required String inviterEmail,
    required String recipientName,
  }) {
    return '''
Hi $recipientName,

$inviterName ($inviterEmail) invited you to join SMARTPLAYER.
Create your account at https://smartplayer.app and connect as friends!

If you don't want to receive these emails, you can ignore this message.
''';
  }
}
