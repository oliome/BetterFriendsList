# Forever update automation

The Lua files and TOC live at the repository root. The release packager places them in one `BetterFriendsList/` directory inside the install ZIP.

The hourly workflow follows FriendlyNameplateGuild's build detection and failure reporting. It reads Blizzard's live `wowf` version table. A newer build of the known patch increments the addon patch version, runs the checks, pushes a commit and tag atomically, and publishes an installable ZIP to GitHub Releases. Unchanged builds stay quiet. Failed checks open a deduplicated issue.

The checkpoint tracks the latest checked Forever build in `wow-version.json`, with Interface 16001 verified for patch 1.60.1. An unfamiliar patch requires its actual Interface value. The optional `FOREVER_BUILD_FEED_URL` repository variable accepts the same exact-build HTTPS feed as FriendlyNameplateGuild. Automated releases use beta tags while `runtime_ready` is false.

Manual addon changes must update both the TOC version and `addon_version` in `wow-version.json`. A pushed `v*` tag runs checks and publishes the ZIP. The update workflow packages directly because tags pushed using `GITHUB_TOKEN` do not start another workflow. Rerun a tag build to recover an interrupted release upload.

These workflows activate after being pushed to the default branch with GitHub Actions enabled. Schedules can be delayed. The checks cover mocked UI behavior and update detection. Live game compatibility still needs an in-game check.
