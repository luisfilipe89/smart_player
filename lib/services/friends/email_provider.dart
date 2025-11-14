import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'email_service_instance.dart';
import '../../providers/infrastructure/firebase_providers.dart';

// Email service provider
final emailServiceProvider = Provider<EmailServiceInstance>((ref) {
  final database = ref.watch(firebaseDatabaseProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return EmailServiceInstance(database, auth);
});

// Email actions provider
final emailActionsProvider = Provider<EmailActions>((ref) {
  final emailService = ref.watch(emailServiceProvider);
  return EmailActions(emailService);
});

class EmailActions {
  final EmailServiceInstance _emailService;

  EmailActions(this._emailService);

  Future<bool> sendFriendInviteEmail({required String recipientEmail}) async {
    return await _emailService.sendFriendInviteEmail(
        recipientEmail: recipientEmail);
  }

  Future<bool> canSendInviteToEmail(String email) async {
    return await _emailService.canSendInviteToEmail(email);
  }
}
