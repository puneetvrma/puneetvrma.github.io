# Puneet Verma — academic research website

Public website: https://puneetvrma.github.io/

A responsive, buildless academic site based on the supplied CV. The published site excludes professional employment, associated government projects, original CV uploads, personal phone numbers and referee details.

## Content

- `index.html`: research profile, selected publications, appointments, teaching and contact.
- `publications/index.html`: 62 searchable bibliography entries transcribed from the CV. Paper links are explicitly labelled Google Scholar title searches; no unverified DOI links are used.
- `cv/index.html`: printable academic-only CV. Use **Print / save as PDF** for a PDF copy.
- `publications.json`: machine-readable bibliography.
- `style.css` and `script.js`: responsive styles and progressive enhancements. All publications remain readable without JavaScript.
- `_config.yml`: GitHub Pages configuration that excludes unused legacy template pages and assets from publication.

## Local preview

Run `python3 -m http.server 8000` from this directory and open http://localhost:8000/. No package installation or compilation is required.

## GitHub Pages

The repository uses the `master` branch. Publish from `master` / root. Existing template sources remain in the repository but are excluded by `_config.yml`. A push to the publishing branch triggers GitHub Pages.

## Editing

Edit the HTML for page content. When updating bibliography entries, keep `publications/index.html`, selected homepage entries and `publications.json` consistent. Dates and bibliographic details reflect the supplied CV; publication and appointment updates should be checked against authoritative records before changing them.
