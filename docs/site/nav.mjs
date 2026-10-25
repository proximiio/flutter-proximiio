// Navigation manifest for the Proximi.io Flutter SDK documentation site.
//
// Single source of truth for sidebar order, page titles in breadcrumbs and pagers, and which
// fragments the build expects under `content/`. A nav entry with slug "a/b" is fed by
// `content/a/b.html`; the empty slug "" is fed by `content/index.html`.
//
// The section set and slugs mirror `proximiio-ios-sdk-v6/docs/site/nav.mjs` and the Android site,
// so a reader who knows one site knows the others. The Flutter plugin bridges the parts of SDK v6
// listed here; sections for SDK features the plugin does not bridge yet (phone-native UWB,
// venue-side RTLS, Live view) are absent rather than empty. Flutter-only pages (architecture of the
// bridge, platform differences) are additions inside the existing sections.

export const SITE = {
  /** Product name shown in the header lockup. */
  name: "Proximi.io Flutter SDK",
  /** Eyebrow under the product name. */
  version: "v6",
  /** Suffix appended to every <title>. */
  titleSuffix: "Proximi.io Flutter SDK v6",
  /** Repository link in the header. */
  repoUrl: "https://github.com/proximiio/flutter-proximiio",
};

/**
 * @typedef {{ slug: string, label: string }} NavItem
 * @typedef {{ label: string, collapsed?: boolean, items: NavItem[] }} NavSection
 * @type {NavSection[]}
 */
export const NAV = [
  {
    label: "Getting started",
    items: [
      { slug: "", label: "What is Proximi.io Flutter SDK" },
      { slug: "getting-started/installation", label: "Installation" },
      { slug: "getting-started/quickstart", label: "Quick start" },
      { slug: "getting-started/permissions", label: "Permissions" },
    ],
  },
  {
    label: "Core concepts",
    items: [
      { slug: "concepts/architecture", label: "Architecture" },
      { slug: "concepts/lifecycle", label: "Lifecycle and streams" },
      { slug: "concepts/positioning", label: "Positioning" },
      { slug: "concepts/beacons", label: "Beacons" },
      { slug: "concepts/data-model", label: "Data model" },
      { slug: "concepts/coordinates", label: "Coordinates and floors" },
    ],
  },
  {
    label: "Guides",
    items: [
      { slug: "guides/foreground", label: "Foreground positioning" },
      { slug: "guides/background", label: "Background positioning" },
      { slug: "guides/geofences-and-pois", label: "Geofences and POIs" },
      { slug: "guides/wayfinding", label: "Wayfinding" },
      { slug: "guides/simulator", label: "Simulator and dev mode" },
      { slug: "guides/tuning", label: "Configuration presets" },
      { slug: "guides/offline-and-sync", label: "Offline and sync" },
      { slug: "guides/analytics", label: "Visitor analytics" },
      { slug: "guides/diagnostics", label: "Diagnostics and logging" },
      { slug: "guides/errors", label: "Errors and failure handling" },
    ],
  },
  {
    label: "API reference",
    items: [
      { slug: "api/proximiio", label: "Proximiio" },
      { slug: "api/configuration", label: "ProximiioConfiguration" },
      { slug: "api/streams", label: "Streams" },
      { slug: "api/models", label: "Models" },
    ],
  },
  {
    label: "Reference",
    items: [
      { slug: "reference/platform-differences", label: "Platform differences" },
      { slug: "reference/migration", label: "Migrating from 1.x" },
      { slug: "reference/troubleshooting", label: "Troubleshooting" },
      { slug: "reference/versioning", label: "Versioning and releases" },
    ],
  },
];
