import 'dart:async';

import 'package:flutter_bunnymark/bunnymark.dart';
import 'package:flutter_bunnymark/core/core.dart';

void main() {
  runZonedGuarded(
    () async {
      final bunnymark = Bunnymark();
      Core.ensure(game: bunnymark);
    },
    (error, stack) {
      print('Uncaught error: $error\n$stack');
    },
  );
}
