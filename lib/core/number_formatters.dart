import 'package:intl/intl.dart';

final NumberFormat _wholeNumberFormat = NumberFormat.decimalPattern('en_US');

String formatElevationMetres(int metres) => _wholeNumberFormat.format(metres);
