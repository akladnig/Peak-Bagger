import 'package:peak_bagger/models/contact.dart';

import '../objectbox.g.dart';

abstract class ContactStorage {
  List<Contact> getAll();

  Contact? getById(int id);

  int put(Contact contact);

  bool remove(int id);
}

class ObjectBoxContactStorage implements ContactStorage {
  ObjectBoxContactStorage(Store store) : _box = store.box<Contact>();

  final Box<Contact> _box;

  @override
  List<Contact> getAll() => _box.getAll();

  @override
  Contact? getById(int id) => _box.get(id);

  @override
  int put(Contact contact) => _box.put(contact);

  @override
  bool remove(int id) => _box.remove(id);
}

class InMemoryContactStorage implements ContactStorage {
  InMemoryContactStorage([List<Contact> contacts = const []])
    : _contacts = List<Contact>.from(contacts),
      _nextId = _nextGeneratedId(contacts);

  List<Contact> _contacts;
  int _nextId;

  static int _nextGeneratedId(List<Contact> contacts) {
    return contacts.fold<int>(1, (nextId, contact) {
      return contact.id >= nextId ? contact.id + 1 : nextId;
    });
  }

  @override
  List<Contact> getAll() => List<Contact>.unmodifiable(_contacts);

  @override
  Contact? getById(int id) {
    for (final contact in _contacts) {
      if (contact.id == id) {
        return contact;
      }
    }
    return null;
  }

  @override
  int put(Contact contact) {
    if (contact.id == 0) {
      contact.id = _nextId++;
    } else if (contact.id >= _nextId) {
      _nextId = contact.id + 1;
    }
    _contacts = [
      for (final existing in _contacts)
        if (existing.id != contact.id) existing,
      contact,
    ];
    return contact.id;
  }

  @override
  bool remove(int id) {
    final initialCount = _contacts.length;
    _contacts = _contacts
        .where((contact) => contact.id != id)
        .toList(growable: false);
    return _contacts.length != initialCount;
  }
}

class ContactRepository {
  ContactRepository(Store store) : _storage = ObjectBoxContactStorage(store);

  ContactRepository.test(ContactStorage storage) : _storage = storage;

  final ContactStorage _storage;

  List<Contact> getAllContacts() => _storage.getAll();

  Contact? findById(int id) => _storage.getById(id);

  Contact save(Contact contact) {
    contact.id = _storage.put(contact);
    return contact;
  }

  bool delete(int id) => _storage.remove(id);
}
