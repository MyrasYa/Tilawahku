import '../../../core/preferences/app_preferences.dart';
import '../../prayer/data/city_location_catalog.dart';
import '../../prayer/data/device_location.dart';
import '../../prayer/data/prayer_preferences.dart';
import '../../prayer/domain/prayer_models.dart';

/// Kiblat hanya membutuhkan satu koordinat, jadi lokasinya dibaca dan disimpan
/// lewat preferensi waktu salat yang sudah ada: tidak ada penyimpanan kedua dan
/// satu kali pilih kota berlaku untuk kedua fitur.
class QiblaLocationStore {
  QiblaLocationStore({
    PrayerPreferences? preferences,
    DeviceLocationProvider? deviceLocation,
    CityLocationCatalog? cityCatalog,
  }) : _preferences = preferences ?? PrayerPreferences(const AppPreferences()),
       _deviceLocation = deviceLocation ?? const GeolocatorDeviceLocation(),
       _cityCatalog = cityCatalog ?? CityLocationCatalog();

  final PrayerPreferences _preferences;
  final DeviceLocationProvider _deviceLocation;
  final CityLocationCatalog _cityCatalog;

  Future<WorshipLocation?> loadSavedLocation() async =>
      (await _preferences.load()).location;

  Future<void> saveLocation(WorshipLocation location) =>
      _preferences.saveLocation(location);

  Future<List<WorshipLocation>> loadCities() => _cityCatalog.load();

  Future<WorshipLocation> locateDevice() => _deviceLocation.locate();
}
