import 'package:move_young/utils/service_error.dart';

class ErrorMapping {
  static String toUserMessage(Object error) {
    if (error is NetworkException) {
      return 'Network error, please try again.';
    }
    if (error is AuthException) {
      return 'Please sign in to continue.';
    }
    if (error is PermissionException) {
      return 'You don\'t have permission for this action.';
    }
    if (error is ValidationException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Please check your input and try again.';
    }
    if (error is NotFoundException) {
      return 'Item not found.';
    }
    if (error is AlreadyExistsException) {
      return 'Already exists.';
    }
    return 'Something went wrong. Please try again.';
  }
}
