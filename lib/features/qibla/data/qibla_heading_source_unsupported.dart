import 'qibla_heading.dart';

QiblaHeadingSource createQiblaHeadingSource() =>
    const UnsupportedQiblaHeadingSource();

/// Web dan platform tanpa plugin kompas: tidak ada heading palsu.
class UnsupportedQiblaHeadingSource implements QiblaHeadingSource {
  const UnsupportedQiblaHeadingSource();

  @override
  Future<bool> hasSensors() async => false;

  @override
  Stream<QiblaHeadingSample> watch() => const Stream.empty();
}
