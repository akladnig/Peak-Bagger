import 'package:peak_bagger/models/contact.dart';

class ContactAdminFormState {
  const ContactAdminFormState({
    required this.firstName,
    required this.surname,
    required this.nickname,
  });

  final String firstName;
  final String surname;
  final String nickname;
}

class ContactAdminValidationResult {
  const ContactAdminValidationResult({required this.fieldErrors, this.contact});

  final Map<String, String> fieldErrors;
  final Contact? contact;

  bool get isValid => fieldErrors.isEmpty;
}

class ContactAdminEditor {
  static ContactAdminValidationResult validateAndBuild({
    required Contact source,
    required ContactAdminFormState form,
  }) {
    final firstName = form.firstName.trim();
    final surname = form.surname.trim();
    final nickname = form.nickname.trim();
    if (firstName.isEmpty && surname.isEmpty && nickname.isEmpty) {
      const error = 'Enter a first name, surname, or nickname.';
      return const ContactAdminValidationResult(
        fieldErrors: {'firstName': error, 'surname': error, 'nickname': error},
      );
    }

    return ContactAdminValidationResult(
      fieldErrors: const {},
      contact: Contact(
        id: source.id,
        firstName: firstName,
        surname: surname,
        nickname: nickname,
      ),
    );
  }
}
