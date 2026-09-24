import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/services/contact_admin_editor.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

void main() {
  test('trims a valid contact and composes its display name', () {
    final result = ContactAdminEditor.validateAndBuild(
      source: Contact(id: 4),
      form: const ContactAdminFormState(
        firstName: ' Ada ',
        surname: ' Lovelace ',
        nickname: ' Countess ',
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.contact?.id, 4);
    expect(result.contact?.firstName, 'Ada');
    expect(result.contact?.surname, 'Lovelace');
    expect(result.contact?.nickname, 'Countess');
    expect(contactDisplayName(result.contact!), 'Ada Lovelace');
  });

  test('uses nickname only when both name parts are blank', () {
    final result = ContactAdminEditor.validateAndBuild(
      source: Contact(),
      form: const ContactAdminFormState(
        firstName: ' ',
        surname: '',
        nickname: ' Ada ',
      ),
    );

    expect(result.isValid, isTrue);
    expect(contactDisplayName(result.contact!), 'Ada');
  });

  test('rejects blank contacts and allows duplicate names', () {
    final blank = ContactAdminEditor.validateAndBuild(
      source: Contact(),
      form: const ContactAdminFormState(
        firstName: ' ',
        surname: '',
        nickname: '',
      ),
    );
    final duplicate = ContactAdminEditor.validateAndBuild(
      source: Contact(id: 2),
      form: const ContactAdminFormState(
        firstName: 'Ada',
        surname: 'Lovelace',
        nickname: 'Ada',
      ),
    );

    expect(blank.isValid, isFalse);
    expect(blank.contact, isNull);
    expect(duplicate.isValid, isTrue);
  });
}
