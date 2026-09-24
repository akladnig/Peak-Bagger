import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/contact_repository.dart';

void main() {
  test('save assigns an id to an independent contact', () {
    final repository = ContactRepository.test(InMemoryContactStorage());

    final contact = repository.save(
      Contact(firstName: 'Ada', surname: 'Lovelace', nickname: 'Ada'),
    );

    expect(contact.id, isNonZero);
    expect(repository.getAllContacts(), [contact]);
  });

  test('ObjectBox generates an id for an independent contact', () async {
    final directory = await Directory.systemTemp.createTemp(
      'contact-repository',
    );
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    final store = await openStore(directory: directory.path);
    addTearDown(store.close);

    final contact = ContactRepository(store).save(Contact(nickname: 'Ada'));

    expect(contact.id, isNonZero);
    expect(store.box<Contact>().get(contact.id), isNotNull);
  });
}
