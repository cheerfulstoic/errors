# Open Questions

There are a lot of design considerations that go into the `triage` library. There are still some open questions to be considered. Feel free to open an issue or a discussion on the [GitHub repo](https://github.com/cheerfulstoic/triage).

## Should other atoms / tuples be supported?

Sometimes "results" can be more than just :ok / :error.  Common examples: `:ignore` or `:commit` (both alone and as the label in a tuple).

Should `triage` support these in some way (limited or otherwise)? Should it be something an application can configure?

An argument could be make that one could return things like `{:ok, :ignore}`, `{:error, :ignore}`, `{:ok, {:commit, _}}`

It also shouldn't be the goal that people use `triage` for all types of result objects, so being limited to `:ok` / `:error` results may be just fine.

## Bang syntax

I'm curious what people think about functions like `ok_then` vs `ok_then!`.  The `ok_then!` could be considered a "default" because it doesn't "do" anything. Rather it's the `ok_then` function which actively rescues from exceptions. But it does feel right, in a way, to have a simple convention that `ok_then!` is the one where you can expect exception to come from 🤷‍♂️

## Should `ok_then` return `WrappedError`?

Currently when an exception is raised in the function given to `Triage.ok_then`, it returns a `WrappedError` which "contains" the exception. This `WrappedError` automatically includes context information about the function (the line/number if anonymous and the name of the function if captured). Should the raw exception be returned instead? It wouldn't have STACKTRACE information because that's not on exceptions.

## Should `ok_then!/1` exist?

Calling `ok_then!` functions doesn't catch exceptions.  So is there a difference between calling `ok_then!/1` with some code or just running that code directly?

* `ok_then/1` captures errors
* `ok_then!/2` / `ok_then/2` only execute the function on :ok results and unwrap the result

The `ok_then!/1` function at least has the behavior that you can return a non-result and it will automatically wrap it in `{:ok, _}`, but is that worthwhile enough?
