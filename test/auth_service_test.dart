import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/services/auth_service.dart';

void main() {
  test('logout clears stored current_user and isLoggedIn returns false', () async {
    // Setup mock SharedPreferences with a current_user entry
    SharedPreferences.setMockInitialValues({
      'current_user': '{"id":"1","username":"test","email":"test@example.com","role":"member"}',
    });

    final auth = AuthService();

    // Ensure initial state reflects logged in
    expect(await auth.isLoggedIn(), isTrue);

    // Perform logout
    await auth.logout();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('current_user'), isFalse);
    expect(await auth.isLoggedIn(), isFalse);
  });
}
