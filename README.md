# ios-pipeline

One shared GitHub Actions workflow that builds, signs and uploads any iOS app in
**Sithewok-apps** to TestFlight. App repos call it with a ten-line file, so a fix
here reaches every app on its next build.

Each build runs on a GitHub cloud Mac (`macos-26`, Xcode 26). It signs with a
certificate stored encrypted in the private `ios-certificates` repo
([fastlane match](https://docs.fastlane.tools/actions/match/)) and uploads with an
App Store Connect API key, so no password or 2FA code is involved.

## One-time setup

Save every value marked **SAVE** in a password manager.

1. **Team ID.** developer.apple.com/account → **Membership details**. SAVE the
   10-character Team ID.
2. **API key.** appstoreconnect.apple.com → **Users and Access** →
   **Integrations** → **App Store Connect API** → **Team Keys** → **+**.
   Name it `GitHub CI`, Access **Admin**. SAVE the **Key ID** and **Issuer ID**.
   Download the `.p8` (only possible once) and SAVE its full text, including the
   `BEGIN` and `END` lines. On a phone: rename it to `.txt` in Files to open it.
3. **Certificates repo.** `Sithewok-apps/ios-certificates` must exist, be
   **private**, and start empty.
4. **Token.** GitHub → **Settings** → **Developer settings** → **Personal access
   tokens** → **Fine-grained tokens** → **Generate new token**.
   - Resource owner: **Sithewok-apps**
   - Repository access: **Only select repositories** → `ios-certificates`
   - Permissions: **Contents** → **Read and write**
   - Expiration: 1 year. SAVE the token.
   - If it shows as pending, approve it under the organization's **Settings** →
     **Personal access tokens** → **Pending requests**.
5. **Passphrase.** Make up a strong one. It encrypts the certificates. SAVE it.
6. **Organization secrets.** github.com/Sithewok-apps → **Settings** →
   **Secrets and variables** → **Actions** → **New organization secret**.
   Add each of these with Repository access **All repositories**:

   | Secret | Value |
   | --- | --- |
   | `APPLE_TEAM_ID` | Team ID |
   | `ASC_KEY_ID` | Key ID |
   | `ASC_ISSUER_ID` | Issuer ID |
   | `ASC_KEY_CONTENT` | Full `.p8` text |
   | `CERTS_REPO_URL` | `https://github.com/Sithewok-apps/ios-certificates.git` |
   | `CERTS_REPO_USER` | Your GitHub username |
   | `CERTS_REPO_TOKEN` | Token from step 4 |
   | `MATCH_PASSWORD` | Passphrase from step 5 |

   On GitHub's free plan, organization secrets reach **public** repos only. A
   private app repo needs these eight added under its own **Settings** instead.

## Adding an app

1. **App record.** appstoreconnect.apple.com → **Apps** → **+** → **New App**:
   iOS, a unique name, bundle ID, any SKU. Apple's API can't do this step. If the
   bundle ID isn't in the list yet, run the workflow once (step 4); it registers
   the ID and then stops with a message telling you to create the record.
2. **Workflow file.** Copy [`templates/app-testflight.yml`](templates/app-testflight.yml)
   to `.github/workflows/testflight.yml` in the app repo and fill in its four
   values. The scheme must be **Shared** (checked into `xcshareddata`).
3. **Info.plist.** Set `CFBundleVersion` to `$(CURRENT_PROJECT_VERSION)` and add
   `ITSAppUsesNonExemptEncryption` as Boolean `NO`.
4. **Run it.** GitHub app → the repo → **Actions** → **TestFlight** →
   **Run workflow**. A build takes 15–30 minutes, then Apple processes it for
   10–30 more.

Or ask Claude: *"Set up TestFlight for Sithewok-apps/REPO using
Sithewok-apps/ios-pipeline."* The steps it follows are in [CLAUDE.md](CLAUDE.md).

### Apps built outside Xcode (CMake ports)

If the app's own CI already publishes an unsigned `.ipa` as a GitHub release
asset, use `testflight-ipa.yml` instead. It downloads that IPA, sets the bundle
ID and build number, adds the Xcode/SDK keys and an App Store icon set (from one
1024 px PNG), signs it, and uploads it. No rebuild, so a run takes minutes.

```yaml
jobs:
  ship:
    uses: Sithewok-apps/ios-pipeline/.github/workflows/testflight-ipa.yml@main
    with:
      app_identifier: com.sithewok.mygame
      app_name: My Game
      release_tag: ios-latest                 # release holding the IPA
      ipa_asset: MyGame-unsigned.ipa          # its file name
      icon: packaging/icon.png                # square PNG, ideally 1024 px
    secrets: inherit
```

**App repo outside Sithewok-apps?** Its releases just need to be public. Put
the caller file in this repo instead, with `source_repo: owner/repo`, so it runs
here with the organization's secrets and the app repo needs no secrets or
changes. Example: [`openjkdf2.yml`](.github/workflows/openjkdf2.yml). Run it from
this repo's **Actions** tab.

**Jedi Knight goes by itself.** [`auto-openjkdf2.yml`](.github/workflows/auto-openjkdf2.yml)
("Auto: Jedi Knight builds") checks every hour for a new build of
sithewok13-dev/OpenJKDF2-iOS. When there is one, it starts **TestFlight -
OpenJKDF2** and **Update game links** (Jedi Knight and OpenMoTS only). A run
that failed isn't retried by itself: run it again by hand. To stop it:
**Actions** > **Auto: Jedi Knight builds** > **...** > **Disable workflow**.

### Optional inputs

| Input | Default | Use |
| --- | --- | --- |
| `app_name` | bundle ID | Name shown for a newly registered bundle ID |
| `generate_command` | none | Shell command that creates the `.xcodeproj` first, such as `cmake -G Xcode -B build` |
| `runner` | `macos-26` | A different GitHub macOS runner |

## Inviting testers

App Store Connect → **Users and Access** → **+** (role: Customer Support). Then
your app → **TestFlight** → **Internal Testing** → **+**, make a `Friends` group
with **automatic distribution**, and add them. Up to 100 people, no review. For
a public link, use **External Testing**; Apple reviews the first build of each
version.

## Sideloading kit (Feather, ESign)

Sign any app for your own registered devices with your own account, no
service needed:

1. **Register device** (Actions): a name and the device's UDID (udid.tech
   shows it). Up to 100 iPhones a year.
2. **Make signing kit** (Actions): saves `Sideload.p12` (password: your Match
   passphrase) and `Sideload.mobileprovision` (any app, every registered
   device, one year) on the `sideload` branch of the private `ios-certificates`
   repo (github.com/Sithewok-apps/ios-certificates/tree/sideload).
3. On the phone, open those two files from GitHub in Safari and import them
   into the signing app. Run step 2 again after adding a device.

The kit renews itself: **Make signing kit** checks on the 3rd of each month
and makes a new one when the profile has under 45 days left, then opens an
issue here (GitHub emails it). Load the new files into Feather and re-sign.

### Install links for friends

1. In Feather, sign the app and export the signed `.ipa` to Files.
2. Here: **Releases** > **Draft a new release**, tag starting with `install-`
   (for example `install-myapp`), attach the `.ipa`, **Publish**.
3. A minute later it's on https://sithewok-apps.github.io/ios-pipeline/ with an
   **Install** button. Send that link; it must be opened in Safari, on an
   iPhone that's registered (Register device, then Make signing kit, then
   re-sign).

**Games** (from **Update game links**) stay until the next update, and each
has a page of its own with just its **Install** button, to send to a friend:

- Jedi Knight: https://sithewok-apps.github.io/ios-pipeline/jedi-knight/
- Mysteries of the Sith: https://sithewok-apps.github.io/ios-pipeline/mots/
- Serious Sam: https://sithewok-apps.github.io/ios-pipeline/serious-sam/ and
  https://sithewok-apps.github.io/ios-pipeline/serious-sam-se/

Other links are removed after 30 days. Anyone with the link can download the file
(only registered iPhones can install it), so only share apps you're allowed to.
One-time setup: **Settings** > **Pages** > Source: **GitHub Actions**.

Only for apps you have the right to install (your own, open-source, ones you
obtained legitimately). The kit can sign as you: keep it private.

## Troubleshooting

| What you see | Fix |
| --- | --- |
| 401 or authentication error | Recheck `ASC_KEY_ID`, `ASC_ISSUER_ID`, and that `ASC_KEY_CONTENT` includes the `BEGIN`/`END` lines |
| Secret is empty / "Input required and not supplied" | Repo is private on the free plan, or a secret name is misspelled |
| "No App Store Connect app for …" | Create the app record (Adding an app, step 1) |
| match can't clone the certificates repo | Token expired, lacks Contents read/write, or is pending approval |
| Maximum number of certificates reached | Revoke an unused Distribution certificate on developer.apple.com |
| Certificate expired (yearly) | Revoke it on developer.apple.com, delete its files from `ios-certificates`, run again |
| "Target doesn't support provisioning profiles" | `target` points at a library; use the app target |
| Scheme not found | Mark the scheme **Shared** in Xcode, or fix the name |
| Build number must be higher | `CFBundleVersion` isn't `$(CURRENT_PROJECT_VERSION)` |
| "Missing Compliance" in TestFlight | Add `ITSAppUsesNonExemptEncryption` = `NO` |

Builds expire after 90 days; any new build resets that. Renew the token before it
expires.
