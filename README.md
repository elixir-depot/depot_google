# DepotGoogle

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `depot_s3` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:depot_google, "~> 0.1.0"}
  ]
end
```

Set `:goth` credentials in your `config.exs`. See
[peburrows/goth](https://github.com/peburrows/goth#installation) for more options.

```elixir
config :goth,
  json: File.read!("path/to/google/json/creds.json")
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/depot_s3](https://hexdocs.pm/depot_s3).
