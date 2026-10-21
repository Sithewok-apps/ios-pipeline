# Setting up TestFlight for an app repo

When asked to set up TestFlight for a repo in Sithewok-apps, follow these steps.
The shared workflow is `.github/workflows/testflight.yml` in this repo; app repos
call it, they don't copy it.

## Never

- Ask for, read, print, or store any secret value (API key, `.p8` text, token,
  passphrase). The owner enters secrets in GitHub settings themselves.
- Touch `ios-certificates` except to confirm it exists and is private.
- Add game data or other assets the owner doesn't have rights to ship.
- Set up a repo whose own `AGENTS.md` or `CLAUDE.md` pauses releases.

## Steps

If the app isn't an Xcode project but its CI publishes an unsigned `.ipa`
release asset, use `testflight-ipa.yml` instead (README, "Apps built outside
Xcode"); steps 2 and 4 then don't apply.

1. Read the app repo's own instructions (`AGENTS.md`, `CLAUDE.md`) first.
2. Find the values for the caller file:
   - `xcode_project`: the `.xcodeproj` path. If the project is generated
     (CMake, XcodeGen, Tuist), set `generate_command` instead and use the
     generated path.
   - `target`: the application target (`productType` ending in
     `.application` in `project.pbxproj`), not a library or extension.
   - `scheme`: a shared scheme under `*.xcodeproj/xcshareddata/xcschemes/`
     that builds that target. If none exists, create one there.
   - `app_identifier`: the target's `PRODUCT_BUNDLE_IDENTIFIER`. If it's a
     placeholder or belongs to someone else, ask the owner for theirs
     (convention: `com.sithewok.<app>`), and update the project to match.
3. Add `.github/workflows/testflight.yml` from `templates/app-testflight.yml`
   with those values. Keep `secrets: inherit` and the `@main` ref.
4. In the app's `Info.plist`: `CFBundleVersion` = `$(CURRENT_PROJECT_VERSION)`,
   and `ITSAppUsesNonExemptEncryption` = `false`.
5. Check: lint the workflow with actionlint if available, and confirm every
   path in it exists in the repo.
6. Push on a branch and open a PR. Tell the owner the one manual step left: the
   App Store Connect app record for that bundle ID. Mention that a private repo
   needs the eight secrets added to the repo itself.
7. When the owner says the record exists, start the workflow, read the job log
   on failure, fix in the app repo (or here if the fault is shared), and run
   again until it uploads. Use the README's troubleshooting table.
