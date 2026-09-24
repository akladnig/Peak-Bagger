import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/contact_repository.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

import 'objectbox_admin_robot.dart';

void main() {
  testWidgets('Contacts can be added, edited, searched, and deleted', (
    tester,
  ) async {
    final contacts = ContactRepository.test(
      InMemoryContactStorage([
        Contact(id: 1, firstName: 'Existing', surname: 'Contact'),
      ]),
    );
    final robot = ObjectBoxAdminRobot(tester);
    await robot.pumpApp(
      repository: _ContactObjectBoxAdminRepository(contacts),
      contactRepository: contacts,
    );

    await robot.openAdminFromMenu();

    expect(find.text('Contacts'), findsOneWidget);
    expect(robot.addContactButton, findsOneWidget);
    expect(robot.addPeakButton, findsNothing);

    await robot.startCreatingContact();
    expect(find.text('New Contact'), findsOneWidget);
    await robot.enterContactField('nickname', 'Discarded');
    await tester.tap(robot.contactCancelButton);
    await tester.pumpAndSettle();
    expect(contacts.getAllContacts(), hasLength(1));

    await robot.startCreatingContact();
    expect(find.text('New Contact'), findsOneWidget);

    await robot.saveContact();
    expect(contacts.getAllContacts(), hasLength(1));
    expect(
      find.text('Enter a first name, surname, or nickname.'),
      findsWidgets,
    );

    await robot.enterContactField('firstName', ' Ada ');
    await robot.enterContactField('surname', ' Lovelace ');
    await robot.enterContactField('nickname', ' Countess ');
    expect(find.text('Ada Lovelace'), findsOneWidget);

    await robot.saveContact();

    final saved = contacts.getAllContacts().singleWhere(
      (contact) => contact.id != 1,
    );
    expect(saved.id, isNonZero);
    expect(saved.firstName, 'Ada');
    expect(saved.surname, 'Lovelace');
    expect(saved.nickname, 'Countess');
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    expect(
      container.read(objectboxAdminProvider).selectedRow?.primaryKeyValue,
      saved.id,
    );

    await robot.startEditingContact();
    await robot.enterContactField('nickname', ' Changed ');
    await tester.tap(robot.contactCancelButton);
    await tester.pumpAndSettle();
    expect(contacts.findById(saved.id)?.nickname, 'Countess');

    await robot.startEditingContact();
    await robot.enterContactField('firstName', ' Grace ');
    await robot.saveContact();
    expect(contacts.findById(saved.id)?.firstName, 'Grace');
    expect(find.text('Grace Lovelace'), findsOneWidget);

    await tester.enterText(robot.searchField, 'COUNTESS');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.text('Grace'), findsWidgets);

    await tester.enterText(robot.searchField, '${saved.id}');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);

    await tester.enterText(robot.searchField, '');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.tap(robot.contactDeleteButton(saved.id));
    await tester.pumpAndSettle();
    expect(find.text('Delete Contact?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(contacts.findById(saved.id), isNull);
    expect(robot.contactDeleteButton(saved.id), findsNothing);
  });
}

class _ContactObjectBoxAdminRepository implements ObjectBoxAdminRepository {
  _ContactObjectBoxAdminRepository(this.contacts);

  final ContactRepository contacts;

  static const _entity = ObjectBoxAdminEntityDescriptor(
    name: 'Contact',
    displayName: 'Contacts',
    primaryKeyField: 'id',
    primaryNameField: 'firstName',
    fields: [
      ObjectBoxAdminFieldDescriptor(
        name: 'id',
        typeLabel: 'int',
        nullable: false,
        isPrimaryKey: true,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'firstName',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: true,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'surname',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'nickname',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
    ],
  );

  @override
  List<ObjectBoxAdminEntityDescriptor> getEntities() => const [_entity];

  @override
  Future<List<ObjectBoxAdminRow>> loadRows(
    ObjectBoxAdminEntityDescriptor entity, {
    required String searchQuery,
    required bool ascending,
  }) async {
    return objectBoxAdminFilterAndSortRows(
      entity,
      rows: contacts.getAllContacts().map(contactToAdminRow).toList(),
      searchQuery: searchQuery,
      ascending: ascending,
    );
  }

  @override
  Future<String> exportGpxFile(ObjectBoxAdminRow row) {
    throw UnsupportedError('Contacts do not export GPX files.');
  }
}
