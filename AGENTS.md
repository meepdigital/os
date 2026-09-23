# Agent instructions

- Never use semicolons when generating JavaScript code.

- Whenever making changes to `./installer` that add or remove a page, insert a
  page partway through the flow, or move a page, re-index the installer pages
  afterward. Keep the `installer/pages/page-XX-*.js` filenames, exported page
  identifiers, imports, and the ordered `pages` array in `installer/renderer.js`
  sequential and consistent.
