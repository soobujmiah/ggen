# Licensing and provenance register

**Rule:** inclusion means owner-approved private preservation, not verified redistribution permission.

| Asset group | Current evidence | State | Distribution rule |
|---|---|---|---|
| RGEN code concepts | Private reference repo; no top-level code license found | UNRESOLVED | Do not copy source; reimplement contracts unless owner/license establishes otherwise |
| RGENCalligraphy fonts | Bundled `RGENCalligraphy-LICENSE.md`; derived from TeX Gyre Chorus/GUST-LPPL account in source docs | DOCUMENTED, review needed | Preserve notice; legal review before public release |
| Genuine Lucida fonts | Proprietary according to RGEN docs; files included | BLOCKED | Private owner use only; exclude from public builds unless license proof exists |
| Noto fonts | Files included; no notices copied with current RGEN asset set | INCOMPLETE | Add exact upstream/OFL notices before distribution |
| `ben.traineddata` | SHA matches reviewed upstream profile in NpuHub; expected Apache-2.0 | PARTIAL | Record exact commit/source/license file |
| `eng.traineddata` | Exact hash recorded; upstream commit not recorded | INCOMPLETE | Resolve source/commit/license |
| PDF templates | Source RGEN production files; ownership/authorization not separately documented | UNRESOLVED | Private approved use only |
| Government logo, seals, borders, watermarks | Source files present; rights not documented | UNRESOLVED/SENSITIVE | No public redistribution until owner/usage authority confirmed |
| Signature images | Source files present; consent/scope not documented | RESTRICTED/SENSITIVE | Never expose publicly; require owner/operator authorization and abuse controls |
| Syncfusion runtime | Not copied into Phase 0; future Flutter dependency | LICENSE DECISION REQUIRED | Confirm community/commercial eligibility before implementation/distribution |
| BG segmentation model | Not copied; exact current hash known in audit but immutable upstream source/license dossier incomplete | NOT ADMITTED | Do not import until model provenance review passes |

## Required fields before a distributable release

Canonical name, upstream URL, immutable version/commit, SHA-256, byte size, SPDX license, license text/notice, copyright owner, modification state, distribution permission, attribution placement, and product usage constraints.
