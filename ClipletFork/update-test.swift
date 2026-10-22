import AppKit

@main struct UpdateTest {
  @MainActor static func main() {
    precondition(SoftwareUpdater.version("cliplet-v1.2.3") == [1, 2, 3])
    for tag in ["2.7.1", "maccy-v9.0.0", "cliplet-v1.2", "cliplet-v1.2.3-beta", "cliplet-v-1.2.3"] {
      precondition(SoftwareUpdater.version(tag) == nil)
    }
    let valid = SoftwareUpdater.Release(tag_name: "cliplet-v1.0.1",
      html_url: "https://github.com/TC023456-sys/Cliplet/releases/tag/cliplet-v1.0.1", draft: false, prerelease: false)
    precondition(SoftwareUpdater.trustedURL(valid) != nil)
    let wrong = SoftwareUpdater.Release(tag_name: valid.tag_name,
      html_url: "https://github.com/p0deje/Maccy/releases/tag/cliplet-v1.0.1", draft: false, prerelease: false)
    precondition(SoftwareUpdater.trustedURL(wrong) == nil)
    let draft = SoftwareUpdater.Release(tag_name: valid.tag_name, html_url: valid.html_url, draft: true, prerelease: false)
    precondition(SoftwareUpdater.trustedURL(draft) == nil)
    print("PASS: only maintainer Cliplet stable releases accepted; upstream/draft/malformed releases rejected")
  }
}
