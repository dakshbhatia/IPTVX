**Comparison Target**

- Source visual truth: `/var/folders/2w/n3x_b2dn567bp586d2lgrxch0000gn/T/codex-clipboard-87bbdaa3-3df1-48e6-a230-9f3454252f14.png`
- Implementation capture: `/tmp/dbstream-home-verify.dzE9Ap/dbstream-home.png`
- Source pixels: 1586 × 992. Implementation pixels: 3024 × 1964, captured at the native macOS display scale.
- Intended state: populated DBStream Home with movie/series backdrops and Continue Watching.
- Captured state: fresh isolated macOS install at Add Provider. It has no catalog, so Home cannot render a hero or a real Continue Watching rail.

**Findings**

- [P1] Exact Option 1 visual comparison is blocked by an unmatched content state.
  Location: Home screen capture.
  Evidence: the reference contains real cinematic catalogue artwork; the isolated build has no playlist or watched title.
  Impact: a truthful comparison cannot substitute fabricated shows or generated artwork for the user's playlist.
  Fix: load a legal VOD-capable test playlist (or a private VOD-enabled provider), open Home, then capture the populated Home state at the same desktop window size.

**Implemented before capture**

- Reduced the oversized Home hero and added a neutral black cinema vignette for readable title treatment.
- Made the Home title hierarchy more cinematic and reserved the DBStream red for intentional primary actions.
- Changed Recently Watched to a real wide-card rail with real artwork, resume progress, live treatment, and context-menu behavior intact.
- Simplified the provider setup screen by removing nonessential privacy and instructional text on macOS, iOS, and tvOS.
- Reworded the idle EPG diagnostic so an unconfigured guide is no longer reported as a misleading failed refresh.

**Required Fidelity Surfaces**

- Fonts and typography: updated Home hero title uses rounded, high-weight system typography; full visual comparison remains blocked pending populated data.
- Spacing and layout rhythm: hero height is reduced to 640 points on macOS/tvOS and 560 on iOS; wide cards use a consistent 16-point rail gap.
- Colors and visual tokens: dark neutral cinema treatment with one DBStream red primary action; no coloured setup gradients were introduced.
- Image quality and asset fidelity: runtime uses the user's remote catalog art only; no generated programming imagery or fake catalog placeholders were used.
- Copy and content: provider setup copy is intentionally reduced to the field labels and the action; live-only providers remain routed to Live TV.

**Implementation Checklist**

1. Add a legal playlist that includes movie or series metadata/backdrops.
2. Launch DBStream, play one title, and return to Home.
3. Capture the populated macOS Home at the reference window size.
4. Re-run the comparison and resolve any remaining P1/P2 visual differences.

**Follow-up Polish**

- Consider a purpose-built live-only Home hero after observing a real provider with suitable wide channel artwork; do not invent featured programming for a live-only playlist.

final result: blocked
