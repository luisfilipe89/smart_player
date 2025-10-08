// lib/services/email_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class EmailService {
  static FirebaseDatabase get _db => FirebaseDatabase.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Send a friend invite email using Firebase Trigger Email extension
  /// This writes to the 'mail' collection which triggers the email extension
  static Future<bool> sendFriendInviteEmail({
    required String recipientEmail,
    required String recipientName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final String inviterName =
          user.displayName ?? _deriveNameFromEmail(user.email) ?? 'Someone';
      final String inviterEmail = user.email ?? '';

      // Generate unique email ID
      final String emailId = const Uuid().v4();

      // Create email document for Firebase Trigger Email extension
      final Map<String, dynamic> emailData = {
        'to': recipientEmail,
        'message': {
          'subject': 'Join me on MoveYoung!',
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
            'appName': 'MoveYoung',
            'inviteLink':
                'https://moveyoung.app/invite?email=${Uri.encodeComponent(recipientEmail)}',
          },
        },
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      };

      // Write to mail collection to trigger email extension
      await _db.ref('mail/$emailId').set(emailData);

      // Also store invite tracking for analytics
      await _db.ref('emailInvites/$emailId').set({
        'fromUid': user.uid,
        'toEmail': recipientEmail,
        'toName': recipientName,
        'status': 'sent',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate HTML email content
  static String _generateInviteEmailHtml({
    required String inviterName,
    required String inviterEmail,
    required String recipientName,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Join me on MoveYoung!</title>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #0077B6; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
    .button { display: inline-block; background: #0077B6; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
    .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🏃‍♂️ MoveYoung</h1>
    </div>
    <div class="content">
      <h2>Hi \$recipientName!</h2>
      <p><strong>\$inviterName</strong> (\$inviterEmail) has invited you to join MoveYoung, the app for finding and organizing sports activities!</p>
      
      <p>With MoveYoung you can:</p>
      <ul>
        <li>🎯 Find sports activities near you</li>
        <li>👥 Connect with friends and other players</li>
        <li>⚽ Create and join games</li>
        <li>📅 Never miss an activity again</li>
      </ul>
      
      <p style="text-align: center;">
        <a href="https://moveyoung.app/invite?email=\${Uri.encodeComponent(recipientEmail)}" class="button">
          Join MoveYoung Now
        </a>
      </p>
      
      <p>Download the app and start your sports journey today!</p>
    </div>
    <div class="footer">
      <p>This invitation was sent by \$inviterName via MoveYoung.</p>
      <p>If you don't want to receive these emails, you can ignore this message.</p>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Generate plain text email content
  static String _generateInviteEmailText({
    required String inviterName,
    required String inviterEmail,
    required String recipientName,
  }) {
    return '''
Hi \$recipientName!

\$inviterName (\$inviterEmail) has invited you to join MoveYoung, the app for finding and organizing sports activities!

With MoveYoung you can:
- Find sports activities near you
- Connect with friends and other players  
- Create and join games
- Never miss an activity again

Join MoveYoung: https://moveyoung.app/invite?email=\${Uri.encodeComponent(recipientEmail)}

Download the app and start your sports journey today!

---
This invitation was sent by \$inviterName via MoveYoung.
If you don't want to receive these emails, you can ignore this message.
''';
  }

  /// Derive name from email address
  static String? _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return null;
    final String prefix = email.split('@').first;
    final String cleaned = prefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (cleaned.isEmpty) return prefix;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  /// Check if email invite was sent recently (rate limiting)
  static Future<bool> canSendInviteToEmail(String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Check for recent invites to this email (max 1 per hour)
      final now = DateTime.now().millisecondsSinceEpoch;
      final oneHourAgo = now - (60 * 60 * 1000);

      final invitesRef = _db.ref('emailInvites');
      final snapshot =
          await invitesRef.orderByChild('fromUid').equalTo(user.uid).get();

      if (snapshot.exists) {
        final Map data = snapshot.value as Map;
        for (final invite in data.values) {
          if (invite is Map) {
            final inviteEmail = invite['toEmail']?.toString() ?? '';
            final inviteTime = invite['createdAt'] as int? ?? 0;
            if (inviteEmail.toLowerCase() == email.toLowerCase() &&
                inviteTime > oneHourAgo) {
              return false; // Recent invite exists
            }
          }
        }
      }

      return true;
    } catch (e) {
      return true; // Allow on error
    }
  }
}
