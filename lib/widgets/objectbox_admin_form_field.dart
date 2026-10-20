import 'package:flutter/material.dart';
import 'package:peak_bagger/services/objectbox_admin_field_policy.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/widgets/objectbox_admin_read_only_value.dart';

/// The same model-backed eligibility used by Schema, not a second field list.
bool objectBoxAdminPermitsInput(
  ObjectBoxAdminEntityDescriptor entity,
  String field,
  AdminFieldInput input,
) => entity.fields.any(
  (descriptor) =>
      descriptor.name == field &&
      descriptor.canEdit &&
      descriptor.metadata?.input == input,
);

/// Hand-built forms choose their controls/validators; this boundary only gates
/// direct input. Unknown, generated and primary-key fields fail closed.
Widget objectBoxAdminTextFormField({
  required ObjectBoxAdminEntityDescriptor entity,
  required String field,
  required Object? recordId,
  required Key key,
  required TextEditingController controller,
  required InputDecoration decoration,
  required bool enabled,
  required ValueChanged<String> onChanged,
  TextInputType? keyboardType,
  bool multiline = false,
}) {
  if (!objectBoxAdminPermitsInput(entity, field, AdminFieldInput.text)) {
    return ObjectBoxAdminReadOnlyFormValue(
      key: key,
      valueKey: ValueKey((entity.name, recordId, field)),
      label: decoration.labelText ?? field,
      text: controller.text,
    );
  }
  return TextFormField(
    key: key,
    controller: controller,
    enabled: enabled,
    decoration: decoration,
    keyboardType: multiline ? TextInputType.multiline : keyboardType,
    // RenderEditable measures wrapping/line height using the active style and
    // TextScaler, scrolls its full draft internally, and keeps decoration outside
    // the content cap. Empty/short drafts retain their natural one-line minimum.
    minLines: 1,
    maxLines: multiline ? 5 : 1,
    onChanged: onChanged,
  );
}
