# ReqTelemetry

<!-- MDOC !-->

`Req` plugin to instrument requests with `:telemetry` events.

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

## Logging

`ReqTelemetry` defines a default logger that can be used by adding the following to your
application's `start/2` callback:

    @impl true
    def start(_type, _args) do
      ReqTelemetry.attach_default_logger()

      children = [
        ...
      ]

      Supervisor.start_link(...)
    end

See `ReqTelemetry.attach_default_logger/1` for options.

<!-- MDOC !-->

## Installation

`req_telemetry` is not yet available through Hex. In the meantime, you can install
it by adding the repository directly:

```elixir
def deps do
  [
    {:req_telemetry, github: "zachallaun/req_telemetry"}
  ]
end
```

