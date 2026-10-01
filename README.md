# datasuite_public

Public downloads, update feed and issue tracker of [DataSuite](https://datasuite.damurka.com).

Release notes for every version: https://datasuite.damurka.com/en/release-notes/ (also in
[French](https://datasuite.damurka.com/fr/release-notes/) and [Portuguese](https://datasuite.damurka.com/pt/release-notes/)).

## Releasing a version

1. In the editor repository, set `datasuiteVersion` in `product.json` to the new version (or build with the
   `DATASUITE_VERSION` environment variable). The app uses it to show this version's release notes.
2. Publish the release notes: in `datasuite-identity/docs-site`, turn the "Upcoming" page into
   `src/content/{en,fr,pt}/release-notes/<version>.mdx`, add it to `_meta.js` and to the table on the index page, and
   deploy the docs. The docs build also publishes `/<lang>/release-notes/<version>.md`, which the app fetches.
3. Build DataSuite, then run `update-version.ps1` from the editor repository: it writes the update feed
   (`versions/stable/win32/x64/*/latest.json`) and the release body (`versions/release-body.md`, linking to the
   release notes page).
4. Create the GitHub release with that body:
   `gh release create <version> -R aphrcwaro/datasuite_public --title "DataSuite <version>" --notes-file versions/release-body.md <setup files>`
5. Copy the `latest.json` files into `stable/` here and push.
