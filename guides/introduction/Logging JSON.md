# Logging JSON

By default, logs are formatted as human-readable plain text. If you would like to output JSON logs, you can use a library like [`logger_json`](https://github.com/Nebo15/logger_json). The `Triage.log` function sets the `errors_result_details` metadata key as well as setting metadata given by `wrap_context` calls.  You can set these keys as output in your [logger configuration](https://hexdocs.pm/logger/Logger.html#module-metadata).  The `errors_result_details` key gives nested a key/value structure, so it won't be outputted with default logs and makes sense when outputting structured logs like with `json`.

Here is an example of configuring metadata:

```elixir
# config/config.exs
config :logger, :console,
 format: "[$level] $message $metadata\n",
 metadata: [:user_id]
```

To configure `logger_json`, you might use something like this:

```elixir
config :logger, :default_handler,
  formatter:
    LoggerJSON.Formatters.Basic.new(metadata: [:user_id, :errors_result_details])
```

If you were to use `Triage.wrap_context("updating user", user_id: 123)`:

With standard logging you'd get `user_id=123` just like if you gave the metadata to `Logger.error` yourself.

Here is an example of what you might get with `logger_json` (spacing introduced for readability):

```json
{
  "message": "[RESULT] {:error, :not_found}\n    [CONTEXT] updating user %{user_id: 123}",
  "time": "2025-10-24T13:20:06.885Z",
  "metadata": {
    "errors_result_details": {
      "reason": "not_found",
      "type": "error"
    },
    "user_id": 123
  },
  "severity": "error"
}
```
