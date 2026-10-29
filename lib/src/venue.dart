import 'value.dart';

/// A kind of point of interest (shop, toilet, exit…) that features refer to.
class ProximiioAmenity with ValueEquality {
  /// Creates an amenity.
  const ProximiioAmenity({
    required this.id,
    this.title,
    this.category,
    this.icon,
    this.details,
    this.metadata,
    this.titleTranslations = const {},
  });

  /// Amenity id; features refer to it in `properties.amenity`.
  final String id;

  /// Display name. [localizedTitle] gives it in one language.
  final String? title;

  /// Amenity category id.
  final String? category;

  /// Icon, as a URL or a data URI.
  final String? icon;

  /// Description.
  final String? details;

  /// What the venue's editors attached to the amenity, decoded from JSON (`Map`, `List`, `String`, `num`,
  /// `bool`), such as whether it is listed in search. The SDK does not interpret it.
  final Object? metadata;

  /// Titles by language code, from `title_i18n`.
  final Map<String, String> titleTranslations;

  /// The title in [language] (a code such as `en` or `en-US`): its translation, else the translation of
  /// the base language (`en`), else [title].
  String? localizedTitle([String? language]) => _translation(titleTranslations, language) ?? title;

  @override
  List<Object?> get props => [id, title, category, icon, details, metadata, titleTranslations];
}

/// The translation for [language], else for its base language (`en` for `en-US`); blank ones are skipped.
String? _translation(Map<String, String> translations, String? language) {
  if (language == null) return null;
  for (final key in {language, language.split(RegExp('[-_]')).first}) {
    final translated = translations[key];
    if (translated != null && translated.trim().isNotEmpty) return translated;
  }
  return null;
}

/// A GeoJSON feature of the venue: a POI, a room, a path, a level changer…
class ProximiioFeature with ValueEquality {
  /// Creates a feature.
  const ProximiioFeature({
    required this.id,
    this.type = 'Feature',
    this.geometry,
    this.properties,
    this.level,
    this.featureClass,
    this.propertyType,
    this.isLevelChanger = false,
    this.titleTranslations = const {},
  });

  /// Feature id.
  final String id;

  /// GeoJSON type, `Feature`.
  final String type;

  /// GeoJSON geometry, decoded (`{"type": "Point", "coordinates": [lng, lat]}` …).
  final Map<String, Object?>? geometry;

  /// GeoJSON properties, decoded.
  final Map<String, Object?>? properties;

  /// Level from `properties.level`.
  final double? level;

  /// `properties.class`.
  final String? featureClass;

  /// `properties.type` (`poi`, `elevator`, `staircase`, …).
  final String? propertyType;

  /// Whether the feature is an elevator, staircase, escalator, ramp or hill.
  final bool isLevelChanger;

  /// Titles by language code, from `properties.title_i18n`.
  final Map<String, String> titleTranslations;

  /// Title in [language] (a code such as `en` or `en-US`): its translation, else the translation of the base
  /// language (`en`), else `properties.title`.
  String? title([String? language]) {
    final translated = _translation(titleTranslations, language);
    if (translated != null) return translated;
    final plain = properties?['title'];
    return plain is String ? plain : null;
  }

  @override
  List<Object?> get props => [
    id,
    type,
    geometry,
    properties,
    level,
    featureClass,
    propertyType,
    isLevelChanger,
    titleTranslations,
  ];

  @override
  String toString() => 'ProximiioFeature($id, $propertyType, level $level)';
}

/// A department of a place; positioning settings can differ per department.
class ProximiioDepartment with ValueEquality {
  /// Creates a department.
  const ProximiioDepartment({required this.id, this.name, this.placeId, this.floorId, this.tags, this.metadata});

  /// Department id.
  final String id;

  /// Display name.
  final String? name;

  /// Id of the place.
  final String? placeId;

  /// Id of the floor.
  final String? floorId;

  /// Tags set in the Proximi.io Portal.
  final List<String>? tags;

  /// Custom metadata, decoded from JSON.
  final Object? metadata;

  @override
  List<Object?> get props => [id, name, placeId, floorId, tags, metadata];
}

/// One stop of a [ProximiioJourney].
class JourneyWaypoint with ValueEquality {
  /// Creates a waypoint.
  const JourneyWaypoint({
    this.latitude,
    this.longitude,
    this.level,
    this.floorId,
    this.label,
    this.dwell,
    this.speed,
    this.transition,
  });

  /// Latitude.
  final double? latitude;

  /// Longitude.
  final double? longitude;

  /// Level.
  final double? level;

  /// Floor id.
  final String? floorId;

  /// Label shown for the stop.
  final String? label;

  /// How long to stay at the stop.
  final Duration? dwell;

  /// Walking speed to this stop, in m/s.
  final double? speed;

  /// Transition time to this stop.
  final Duration? transition;

  @override
  List<Object?> get props => [latitude, longitude, level, floorId, label, dwell, speed, transition];
}

/// A predefined multi-stop journey edited in the Proximi.io Portal or Map Editor.
class ProximiioJourney with ValueEquality {
  /// Creates a journey.
  const ProximiioJourney({
    required this.waypoints,
    required this.displayName,
    this.id,
    this.organizationId,
    this.name,
    this.placeId,
    this.speed,
  });

  /// Journey id.
  final String? id;

  /// Organisation id.
  final String? organizationId;

  /// Name.
  final String? name;

  /// Place id.
  final String? placeId;

  /// Default walking speed, in m/s.
  final double? speed;

  /// Stops, in order.
  final List<JourneyWaypoint> waypoints;

  /// Name for display: [name], or a generated one.
  final String displayName;

  @override
  List<Object?> get props => [id, organizationId, name, placeId, speed, waypoints, displayName];

  @override
  String toString() => 'ProximiioJourney($id, $displayName, ${waypoints.length} stops)';
}

/// A kind of venue data. Open-ended: newer SDKs can report kinds this release does not list.
extension type const VenueDataKind(String rawValue) implements String {
  /// GeoJSON features (POIs, paths, level changers).
  static const features = VenueDataKind('features');

  /// Amenities.
  static const amenities = VenueDataKind('amenities');

  /// The map style.
  static const style = VenueDataKind('style');

  /// Floors.
  static const floors = VenueDataKind('floors');

  /// Places.
  static const places = VenueDataKind('places');

  /// Geofences.
  static const geofences = VenueDataKind('geofences');
}

/// Venue data changed: re-read the [kinds] you show.
class VenueDataChange with ValueEquality {
  /// Creates a change.
  const VenueDataChange(this.kinds);

  /// What changed. Each kind is reported only when its whole collection is stored.
  final Set<VenueDataKind> kinds;

  /// Whether [kind] changed.
  bool contains(VenueDataKind kind) => kinds.contains(kind);

  @override
  List<Object?> get props => [kinds];

  @override
  String toString() => 'VenueDataChange($kinds)';
}

/// A step of the venue data synchronisation.
sealed class SyncEvent with ValueEquality {
  const SyncEvent();
}

/// A record was added or changed.
final class SyncUpdated extends SyncEvent {
  /// Creates the event.
  const SyncUpdated({required this.entity, required this.id});

  /// Entity name (`Floor`, `Geofence`, `Feature`, …).
  final String entity;

  /// Record id.
  final String id;

  @override
  List<Object?> get props => [entity, id];
}

/// A record was deleted.
final class SyncDeleted extends SyncEvent {
  /// Creates the event.
  const SyncDeleted({required this.entity, required this.id});

  /// Entity name.
  final String entity;

  /// Record id.
  final String id;

  @override
  List<Object?> get props => [entity, id];
}

/// A sync pass finished.
final class SyncCompleted extends SyncEvent {
  /// Creates the event.
  const SyncCompleted({required this.applied});

  /// Number of records applied.
  final int applied;

  @override
  List<Object?> get props => [applied];
}

/// A sync pass failed; the SDK retries on the next interval.
final class SyncFailed extends SyncEvent {
  /// Creates the event.
  const SyncFailed({required this.reason});

  /// Description of the failure.
  final String reason;

  @override
  List<Object?> get props => [reason];
}

/// The local store was rebuilt, for example after a schema change; all data is downloaded again.
final class StoreRecreated extends SyncEvent {
  /// Creates the event.
  const StoreRecreated({required this.reason});

  /// Why the store was rebuilt.
  final String reason;

  @override
  List<Object?> get props => [reason];
}
