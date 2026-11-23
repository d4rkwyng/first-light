# Releasing First Light

The [release workflow](.github/workflows/release.yml) builds an arm64
`First Light.app` on the same `macos-15` runner Tankard uses (the image's
selected Xcode; the workflow does not set `DEVELOPER_DIR`), signs it with
Developer ID, notarizes and staples it, and uploads
`First-Light-<version>.zip` to a **draft** GitHub release. It never
publishes that release and never marks it latest.

## Secrets

Repository secrets (Settings → Secrets and variables → Actions):

| Secret | What it is |
|---|---|
| `CERT_P12_BASE64` | Base64 of the exported "Developer ID Application" `.p12` |
| `CERT_P12_PASSWORD` | Password for that `.p12` |
| `NOTARY_APPLE_ID` | Apple ID used for notarization |
| `NOTARY_TEAM_ID` | 10-character Team ID |
| `NOTARY_PASSWORD` | App-specific password from appleid.apple.com |

The workflow imports the certificate into a temporary keychain, stores a
`notarytool` profile in that same keychain, and deletes the keychain as
soon as the signed app is verified, before anything is uploaded (and again
at the end of the job, in case an earlier step failed). `Scripts/build-app.sh --release` is given `CODESIGN_ID` and
`NOTARY_PROFILE`, plus `NOTARY_KEYCHAIN` so `notarytool submit` looks in
that file keychain. Leave `NOTARY_KEYCHAIN` unset for a local release; the
script's signing, notarization, and stapling are otherwise unchanged. The
workflow does not print the secrets.

## Tag

On the commit you want to ship, with a `## [X.Y.Z]` section in
[CHANGELOG.md](CHANGELOG.md):

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

`vX.Y.Z` must be the tag `git describe --tags --abbrev=0` returns on that
commit. `Scripts/build-app.sh` names the zip from that, and the cask
downloads `releases/download/vX.Y.Z/First-Light-X.Y.Z.zip`.

To rebuild an existing tag without pushing it again: Actions → Release →
Run workflow, and pass the tag (for example `v1.0.1`). This only rebuilds a
**draft**. Before it builds or notarizes anything, the workflow fails if
the tag already has a published release, or if it cannot tell. It never
replaces an asset: if the draft already has `First-Light-X.Y.Z.zip`,
delete that asset (or the draft) first. The
workflow checks out `refs/tags/vX.Y.Z` (never a branch of the same name)
and fails if the tag is not of the form `vX.Y.Z` or `vX.Y.Z-suffix`.

Run workflow uses the workflow file from the branch you run it on
(normally `main`), not the copy stored on the tag. It still checks out
and builds `refs/tags/vX.Y.Z`. That matters when the tag carries an older
workflow: `v1.0.1` was tagged before the notarization fix in PR #20, so
its successful build was a Run workflow from `main`.

## Draft

A successful run leaves a draft release on the tag. The asset is
`First-Light-<version>.zip` (a stapled `First Light.app`). The notes are
the changelog section for that version. The draft is not listed as the
latest release. A tag with a `-` suffix (`v1.0.1-rc1`) is also marked as
a prerelease; its zip name keeps the suffix, and its notes come from the
`X.Y.Z` changelog section.

Open the draft and confirm the app before publishing. Gatekeeper should
accept it (`spctl`, `stapler validate`, and `codesign --verify --deep
--strict` already ran in the workflow). The workflow also launched the
unzipped app with `Scripts/smoke-launch.sh`, which hides the runner's
`.build` while the app runs so SwiftPM's build-path fallback cannot mask a
missing resource bundle (the 1.0.0/1.0.1 launch crash). To repeat that on
a downloaded zip: unzip it with `ditto -x -k` and run
`Scripts/smoke-launch.sh "<dir>/First Light.app"`.

## Publish, then the cask

1. Publish the draft on GitHub. That is the only step that makes it the
   public release. Do this by hand, after checking the build. Leave
   **Set as the latest release** checked: GitHub turns it on by default
   for a release that is not a prerelease, and unchecking it publishes
   the release without making it the latest.
2. In [d4rkwyng/homebrew-tap](https://github.com/d4rkwyng/homebrew-tap),
   update `Casks/first-light.rb`: set `version` to `X.Y.Z` (no leading
   `v`) and `sha256` to the zip's digest.

   ```sh
   shasum -a 256 First-Light-X.Y.Z.zip
   ```

   The cask URL is already
   `https://github.com/d4rkwyng/first-light/releases/download/v#{version}/First-Light-#{version}.zip`.
   It installs `First Light.app` and requires Apple silicon and macOS 15
   (Sequoia). The shipped app stays arm64-only, with
   `LSMinimumSystemVersion` 15.0.
