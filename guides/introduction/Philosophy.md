# Philosophy

## Standard results (`:ok`, `:error`, `{:ok, term()}`, `{:error, term()}`)

ok/error results tend to get returned and used throughout a codebase, so having a limited set of possible combinations means there are fewer patterns to expect.

## Variety of small tools that work together (UNIX philosophy)

Triage isn't meant to be the ultimate tool to be used for all code which might return errors. Because we're working with standard results that already exist, you should be able to slip in `triage` tools as needed along side `case`, `with`, and other standard Elixir patterns.

## Avoid macros

Macros might be useful for some specific tools, but the base assumption is that there should be plain functions available to use if desired.

Aside from potential complexity in debugging, you should be able to drop `Triage.*` calls into your code without needing to think if you've added a `require`.
