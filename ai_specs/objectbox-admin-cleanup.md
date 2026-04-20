
# Goal

Splits lib/screens/objectbox_admin_screen.dart files into smaller maintainable files. Should separate UI from business logic and models.

## Previous finding:
 lib/screens/objectbox_admin_screen.dart:300-840 is already internally decomposed into multiple widgets, but they are all trapped in one file. This is a good low-risk mechanical split: move _AdminControls (:300-429), schema widgets (:482-530), data-grid widgets (:532-768), and _DetailsPane (:770-840) into separate files and keep the screen state/lifecycle in the root file.
