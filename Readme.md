Create changes for a local repository with chatgpt / openai / local llm

Install
=======

```Bash
gem install cowrite
```

Usage
=====

- Get [openai key](https://platform.openai.com/settings/profile?tab=api-keys) and export as `COWRITE_API_KEY=`
  (for non-openai see "Options" below)

```bash
cowrite "covert every ruby file to use frozen strings"
> Accept 12 files to be iterate [yes|choose]
> Diff for Rakefile:
- FOO = "foo".freeze
+ # frozen_string_literal: true
+ FOO = "foo"
Apply diff to Rakefile ? [yes]
git commit -am 'fixing rubocop warnings'
```

### Options

- `DEBUG=1` show prompt and answers
- `PARALLEL=10` run queries in parallel
- `COWRITE_URL=` defaults to `https://api.openai.com`
- `COWRITE_API_KEY=`
- pass list of files after `--` separator, especially if you want files that are not in git
- pass wildcards after `--` separator, for example `'add class comments' -- lib/*.rb`
- use in non-interactive mode to make it assume "yes"


Development
===========

- `rake` to run unit tests
- `rake integration` to run integration tests, they need an api key set
- `rake bump:<major|minor|patch>` to create a new version
- `rake release` to release a new version

TODO
====

- local LLM support
- retry on api failures
- make temperatures an option
- make max context an option
- try to send output back to llm with "check this makes sense" to fix bugs
- "question" mode that does not modify


Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![coverage](https://img.shields.io/badge/coverage-100%25-success.svg)](https://github.com/grosser/single_cov)
