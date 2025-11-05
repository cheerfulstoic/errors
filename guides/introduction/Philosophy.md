# Philosophy

## Standard results (`:ok`, `:error`, `{:ok, term()}`, `{:error, term()}`)

ok/error results tend to get returned and used throughout a codebase, so having a limited set of possible combinations means there are fewer patterns to expect.

## Focus on the most useful tools

This library came out of a general desire of seeing the same need for patterns over and over. But in choosing which functions to create, the use-case must exist multiple times in a real-life project. You will find that many of the examples in the docs come from real-life examples.

## The Principle of Least Surprise

As much as possible tools in the `triage` library should be named according to the [principle of least surprise](https://en.wikipedia.org/wiki/Principle_of_least_astonishment). For example, `Triage.map_if` is named because it does a `map` based on `if`logic, `Triage.find_value` is meant to work like `Enum.find_value`, and  `Triage.then` is meant to work similarly to Elixir's `Kernel.then`.

Because naming is so important, feedback and ideas on the API are very welcome!

## Variety of small tools that work together (UNIX philosophy)

Triage isn't meant to be the ultimate tool to be used for all code which might return errors. Because we're working with standard results that already exist, you should be able to slip in `triage` tools as needed along side `case`, `with`, and other standard Elixir patterns.

## Avoid macros

Macros might be useful for some specific tools, but the base assumption is that there should be plain functions available to use if desired.

Aside from potential complexity in debugging, you should be able to drop `Triage.*` calls into your code without needing to think if you've added a `require`.
