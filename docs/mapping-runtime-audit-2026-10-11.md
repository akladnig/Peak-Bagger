# Read-only Mapping runtime observation — 2026-10-11

Executed `dart run tool/mapping_runtime_inventory.dart` from the MacBook checkout.
Observation completed **2026-10-11T10:54:12.244501Z**, root
`/Volumes/Services/Mapping`, transport **SMB (`smbfs`), mac-mini.local/Services**.
Read-only SSH via the existing `mini` alias also confirmed canonical dataset
directories and inspected the external Overpass operating README/fetch script.
No source modification, copy/provisioning or automatic export was performed.

Historical baseline: **25 files, 4,255,657,108 bytes (3.963 GiB)**, audited on
2026-10-10. The 2026-10-11 interview retained paths without remeasuring bytes or
integrity. This fresh executed observation independently derives **25 files,
4,255,657,108 bytes**: **no path or size deviations** from that baseline.
No historical SHA-256 inventory exists here to compare digests for deviations.

Production preflight, required polygon parsing (no geometry cache), all source
readability/containment checks and declared raw-byte regional peak fingerprints
passed (`stalePeakFingerprints: []`). Every listed file was streamed for SHA-256.
Per-file size/mtime and manifest-change checks detected no change during audit.
This is **not a publication-coordinated capture**. Payload-format validation of
peak/highway/feature JSON, TasMap CSV and full DEM blocks was **not** run by this
diagnostic. Digests are fresh identity evidence, not proof of semantic validity.

Role keys link each path to exact consumers/access phases in
[the runtime access table](mapping-runtime-replica-contracts.md#runtime-access-classification):
M = manifest pair; P = required/display polygon; K = peak source; H = highway
source; F = Natural Features; T = TasMap; E = interactive ELVIS DEM;
D = other declared DEM. All current paths have startup existence/readability
checks; only M/P have unconditional startup content reads. K/H/F/T have
conditional ready-app bootstrap/update content reads. P/E have lazy/live Mapping
reads; normal record browsing and routing use local ObjectBox/caches.

| Store-relative path | Current bytes | Role | SHA-256 |
| --- | ---: | --- | --- |
| `DEM/Elvis/elvis_runtime_10m.tif` | 2,322,234,062 | E | `adfe35ee878b07b0172ca5e90d49e54c83a987a4a95b2f4482ab30d3b72a1e9f` |
| `DEM/cop30_hh.tif` | 405,581,332 | D | `3f763ffd599d61d137dd62d6fea79f01e8454c9cfb40204c305722e8ff937e24` |
| `DEM/tasmania_dem_25m.tif` | 284,292,791 | D | `77d38683062df9ca0641aca559873104c71b84a7c2dd07038a7a72ea083984fc` |
| `Features/tasmania_natural_features.json` | 82,695,273 | F | `75565dfe512ec39da4d3e6e240a8599aadfd757a1c3873a02d97a14264f36158` |
| `Highways/friuli-venezia-giulia-highways.json` | 96,506,727 | H | `8f738e72547263a7802a0a2acf07a572f3deb9dc52eac66af3c5fb62495d0d91` |
| `Highways/slovenia-highways.json` | 706,365,113 | H | `7fdf867d10e849ce54f6bcb8ba695065cb08e1aad3b51b2099c2d1a14353c035` |
| `Highways/tasmania-highways.json` | 223,487,946 | H | `1e68062ccbbbb5957f2196bc4270d7df2428e843115ff15b9d374b6c56a9efab` |
| `Highways/veneto-highways.json` | 123,275,043 | H | `952a44fd6ce56350df70f0c611a8cdcc6d245b239a70f4cdcea049a8140aabab` |
| `Maps/tasmap50k.csv` | 9,856 | T | `3a59e442cadda3827363d497963732af4d1e5e2971cc841599ebaaf119bd1cb6` |
| `Peaks/croatia-peaks.json` | 2,758,502 | K | `43f89fd89d4bff1a13a0b3a269bee0157126e79db95b3754c2ddd5b8cac515ac` |
| `Peaks/italy-nord-est-peaks.json` | 2,520,279 | K | `2bbee51c74151c78920dc44178cbd1c9c38c7f631043d95d8118e9bed5a924f8` |
| `Peaks/italy-nord-ovest-peaks.json` | 2,706,776 | K | `17c8820c686125f06ba8dbf8979c2c76743ed24e353e0a1ca22e8f517fb290bd` |
| `Peaks/new-south-wales-peaks.json` | 468,342 | K | `dd12e8b1d87d73ef34581d9a92de49c73cf3765ed47e16d359181e3797a27b45` |
| `Peaks/slovenia-peaks.json` | 2,391,123 | K | `540b38d73ac92ba15b24407f037160ad205ca372e76b1878a4334e5a7f7fd388` |
| `Peaks/tasmania-peaks.json` | 247,376 | K | `78608ed1c4c4a5b7786774eb97eff026e92abacf54b3d7e7fc8ce9f3b6c567f7` |
| `Polygons/croatia.poly` | 17,654 | P | `ea8602553dd37ebcd37098e6b27923cb6a976a8f604f72efff576e7ad565ee6e` |
| `Polygons/friuli-venezia-giulia-islet.poly` | 127 | P | `eef2b2e335d6034e5204f352e80b1037e99e46a6ca7a251c5496fc7c822da186` |
| `Polygons/friuli-venezia-giulia-mainland.poly` | 3,319 | P | `cbfe525133ca79a7a526f468a5054130f8fc341fb93f99653b50fae9545e492c` |
| `Polygons/italy-nord-est.poly` | 28,225 | P | `a7fb592a32b68e07f34a6fc90f04ad3566f8e73e346acc76d1d6ef36faac5e13` |
| `Polygons/italy-nord-ovest.poly` | 15,515 | P | `4d6962b497cca39705476917d3c1749f7bab138b9ec97306d8847ccceb836395` |
| `Polygons/manifest.json` | 288 | M | `63698d41b2b52dba0f2c2d0255038fe9df2a43b280003bb8b2b14039817104b0` |
| `Polygons/new-south-wales.poly` | 27,887 | P | `577b4b49c43c02ccab6d691b4b45d015089298bf5cc5666533328e62abf90784` |
| `Polygons/slovenia.poly` | 10,462 | P | `f5813a8cda35bb54b0d3123e62701165e10068f532b0aa0fda70926f2d7ddc32` |
| `Polygons/tasmania.poly` | 271 | P | `2f218386fc87b627e7c483064c1da2690ba5bb1b92a13240008cf73d6cc06d8e` |
| `region_manifest.json` | 12,819 | M | `1fbd76c5716ec35144b05ebd3b3224b616347c5fe149f689acb4e44a23170399` |

Every future provisioning/refresh must derive and revalidate its own current
set; this dated table is evidence, never a hardcoded replication allowlist.
Space for incoming, captures, protected generations and exports must be audited
separately before provisioning. The full payload-validation matrix and pipeline
contracts were approved by the maintainer during the 2026-10-11 Item 01 review;
no automatic export or replica eligibility is enabled by this audit.
