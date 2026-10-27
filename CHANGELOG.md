# Changelog

## 1.0.1

- Expose immutable version, minimum OS version and upgrade URL in `LatestAppStoreVersion`, with a public initializer.
- Preserve the existing UI convenience API; data-only consumers can own presentation and cancellation decisions.
- Validate HTTP responses and upgrade URLs; build lookup parameters with URLComponents; reject cancelled requests.
- Add eight regression tests, including a normal public import.

The immutable 1.0.1 release is commit `47553afef0a8b59aceee814b3e2804e1ebfdc9cc` and retains the release's Swift tools 6.0 requirement. Its eight tests passed in run 40526455965 on Xcode 26.6 / iOS Simulator 26.5. The maintenance branch preserves main's later Swift tools 6.3 requirement; it does not move the 1.0.1 tag.

Physical-device presentation is not covered by these unit tests.
