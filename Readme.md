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
> found 12 files to be modified [contiue|list|step]
> contiue
> modified lib/foo.rb
...
git diff
# Rakefile
#  - FOO = "foo".freeze
#  + # frozen_string_literal: true
#  + FOO = "foo"
git commit -am 'fixing rubocop warnings'
```

### Options

- `DEBUG=1` show prompt and answers
- `COWRITE_URL=` defaults to `https://api.openai.com`
- `COWRITE_API_KEY=`


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
- parallel execution
- colored output
- try different temperatures to get better results
- try to send output back to llm with "check this makes sense" to fix bugs
- produce diffs and then apply them so we can fix multiple things in 1 file without changing line numbers


Author
======
[Michael Grosser](http://grosser.it)<br/>
michael@grosser.it<br/>
License: MIT<br/>
[![coverage](https://img.shields.io/badge/coverage-100%25-success.svg)](https://github.com/grosser/single_cov)
