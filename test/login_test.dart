import 'package:flutter_test/flutter_test.dart';

void main() {

  test(
    'Login validation test',
    () {

      String email = "test@gmail.com";
      String password = "123456";

      expect(email.isNotEmpty, true);
      expect(password.isNotEmpty, true);

    },
  );

}