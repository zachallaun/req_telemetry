[![Hex.pm](https://img.shields.io/hexpm/v/req_telemetry)](https://hex.pm/packages/req_telemetry)
[![HexDocs.pm](https://img.shields.io/badge/hex.pm-docs-8e7ce6.svg)](https://hexdocs.pm/req_telemetry)
[![CI](https://github.com/zachallaun/protean/actions/workflows/ci.yml/badge.svg)](https://github.com/zachallaun/req_telemetry/actions/workflows/ci.yml)

<!-- MDOC !-->

[`Req`](https://hexdocs.pm/req) plugin to instrument requests with `:telemetry` events.

## Usage

Preferably, `ReqTelemetry` should be the last plugin attached to your `%Req.Request{}`. This
allows `ReqTelemetry` to emit events both at the very start and very end of the request and
response pipelines. In this way, you can observe both the total time spent issuing and
processing the request and response, as well as the time spent only with the request adapter.

    req = Req.new() |> ReqTelemetry.attach()

    req =
      Req.new(adapter: &my_adapter/1)
      |> ReqSomeOtherThing.attach()
      |> ReqTelemetry.attach()

## Events

`ReqTelemetry` produces the following events (in order of event dispatch):

  * `[:req, :request, :pipeline, :start]`
  * `[:req, :request, :adapter, :start]`
  * `[:req, :request, :adapter, :stop]`
  * `[:req, :request, :adapter, :error]`
  * `[:req, :request, :pipeline, :stop]`
  * `[:req, :request, :pipeline, :error]`

You can configure `ReqTelemetry` to produce only `:pipeline` or `:adapter` events; see
`ReqTelemetry.attach/2` for options.

## Logging

`ReqTelemetry` defines a a simple, default logger that logs basic request information and timing.

Here's how a successful request might be logged:

    Req:479128347 - GET https://example.org (pipeline)
    Req:479128347 - GET https://example.org (adapter)
    Req:479128347 - 200 in 403ms (adapter)
    Req:479128347 - 200 in 413ms (pipeline)

For usage and configuration, see `ReqTelemetry.attach_default_logger/1`.

<!-- MDOC !-->

## Installation

`req_telemetry` is available through [hex.pm](https://hex.pm/packages/req_telemetry), and can be
installed by adding the following to your list of dependencies:

```elixir
def deps do
  [
    {:req_telemetry, "~> 0.0.3"}
  ]
end
```

