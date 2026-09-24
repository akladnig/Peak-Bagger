import 'package:objectbox/objectbox.dart';

@Entity()
class Contact {
  @Id()
  int id = 0;

  String firstName;
  String surname;
  String nickname;

  Contact({
    this.id = 0,
    this.firstName = '',
    this.surname = '',
    this.nickname = '',
  });
}
