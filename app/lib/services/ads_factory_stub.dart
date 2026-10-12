import 'package:flutter/foundation.dart';

import 'ads_service.dart';

AdsService createAdsService() => NoopAdsService(simulateRewards: kDebugMode);
