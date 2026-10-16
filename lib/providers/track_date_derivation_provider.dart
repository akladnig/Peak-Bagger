import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/track_date_derivation_service.dart';

final trackDateDerivationServiceProvider = Provider<TrackDateDerivationService>(
  (ref) => TrackDateDerivationService.offline(),
);
