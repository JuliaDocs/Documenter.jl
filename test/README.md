# Notes on the Documenter test suite


## Regenerating / 'fixing' tests

Several of the tests run Documenter on some sample inputs and then compare the
output to a reference document, to check that nothing changed. Sometimes
however it is necessary to update the reference document to deliberate
changes; e.g. when new content was added to one of the inputs.

To update or "fix" the reference documents, simple make sure the
`DOCUMENTER_FIXTESTS` environment variable is set before running the tests.

However, this is not meant to "paper over" regressions. Please carefully check
that result of such a "fixtest" run.
