# AGENTS.md

Project guidance for AI coding assistants.

## Read First

Before making changes, read
[`docs/src/contributing.md`](docs/src/contributing.md).
That document is the primary source of contributor guidance for this
repository.

In particular, follow its formatting rules instead of guessing or applying
generic defaults:

* for Julia code, use the Runic-based workflow described there
  (for example `make format-julia`);
* for JS, HTML, and (S)CSS, follow the Prettier guidance described there;
* for Markdown, follow the Markdown conventions described there and do not
  introduce hard-wrapping or ad hoc list formatting.

## Pull Requests

Open pull requests against `master`, not `release-*`, unless a maintainer
explicitly asks for backport work.

Pull request descriptions must disclose when AI tools were used to prepare the
change.

## Commits

Commits made with material AI assistance must include an appropriate
`Co-authored-by:` trailer.

Keep commit diffs focused and preserve the surrounding style of the code you
touch.

## Changelog

User-visible changes should usually add or update an entry in
[`CHANGELOG.md`](CHANGELOG.md), following the style described in
[`docs/src/contributing.md`](docs/src/contributing.md).

If you are preparing a change for someone else, remind them to check whether a
changelog entry is needed.

## Verification

Run the relevant formatter and the most targeted tests you can for the area you
changed.
