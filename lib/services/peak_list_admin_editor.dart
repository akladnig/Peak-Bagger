import 'package:peak_bagger/models/peak_list.dart';

class PeakListAdminFormState {
  const PeakListAdminFormState({required this.colour});

  final String colour;

  PeakListAdminFormState copyWith({String? colour}) {
    return PeakListAdminFormState(colour: colour ?? this.colour);
  }
}

class PeakListAdminValidationResult {
  const PeakListAdminValidationResult({
    required this.fieldErrors,
    this.peakList,
  });

  final Map<String, String> fieldErrors;
  final PeakList? peakList;

  bool get isValid => peakList != null;
}

class PeakListAdminEditor {
  static PeakListAdminFormState normalize(PeakList peakList) {
    return PeakListAdminFormState(colour: _formatHexColour(peakList.colour));
  }

  static PeakListAdminValidationResult validateAndBuild({
    required PeakList source,
    required PeakListAdminFormState form,
  }) {
    final fieldErrors = <String, String>{};
    final colour = _parseInt(
      value: form.colour,
      fieldName: 'colour',
      fieldErrors: fieldErrors,
    );
    if (fieldErrors.isNotEmpty) {
      return PeakListAdminValidationResult(fieldErrors: fieldErrors);
    }

    return PeakListAdminValidationResult(
      fieldErrors: fieldErrors,
      peakList: source.copyWith(colour: colour!),
    );
  }

  static int? _parseInt({
    required String value,
    required String fieldName,
    required Map<String, String> fieldErrors,
  }) {
    final trimmed = value.trim();
    final parsed = trimmed.startsWith('0x') || trimmed.startsWith('0X')
        ? int.tryParse(trimmed.substring(2), radix: 16)
        : int.tryParse(trimmed);
    if (parsed == null) {
      fieldErrors[fieldName] = '$fieldName must be an integer';
      return null;
    }
    return parsed;
  }

  static String _formatHexColour(int value) {
    return '0x${value.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }
}
