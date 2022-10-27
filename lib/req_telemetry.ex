defmodule ReqTelemetry do
  @moduledoc """
  `Req` plugin to report `:telemetry` events.

  ## Usage

  Preferably, `ReqTelemetry` should be the last plugin attached to your `%Req.Request{}`. This
  allows `ReqTelemetry` to emit events both at the very start and very end of the request and
  response pipelines. In this way, you can observe both the total time spent issuing and
  processing the request and response, as well as the time spent only with the request adapter.

      req = Req.new() |> ReqTelemetry.attach()
      req = Req.new(adapter: &my_adapter/1) |> ReqSomeOtherThing.attach() |> ReqTelemetry.attach()

  See `attach/2` for additional options.

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

  See `attach_default_logger/1` for options.
  """

  require Logger

  @type options :: boolean() | [option]
  @type option :: {:adapter, boolean()} | {:pipeline, boolean()}

  @default_opts %{adapter: true, pipeline: true}
  @no_emit_opts %{adapter: false, pipeline: false}

  @events [
    [:req, :request, :pipeline, :start],
    [:req, :request, :adapter, :start],
    [:req, :request, :adapter, :stop],
    [:req, :request, :adapter, :error],
    [:req, :request, :pipeline, :stop],
    [:req, :request, :pipeline, :error]
  ]

  @doc """
  Installs request, response, and error steps that emit `:telemetry` events.

  ## Options

  Events can be suppressed on a per-request basis using the `:telemetry` option:

    * `telemetry: false` - do not emit telemetry events
    * `telemetry: [pipeline: false]` - do not emit pipeline telemetry events
    * `telemetry: [adapter: false]` - do not emit adapter telemetry events

  These options can also be passed to `attach/2` to set default behavior.

  ## Usage

      req = Req.new() |> ReqTelemetry.attach()
      # %Req.Request{options: %{telemetry: [pipeline: true, adapter: true]}}

      Req.get!(req, url: "https://example.org")

      # Do not emit events
      Req.get!(req, url: "https://example.org", telemetry: false)

      # Do not emit pipeline events
      Req.get!(req, url: "https://example.org", telemetry: [pipeline: false])

      # By default, do not emit events
      req = Req.new() |> ReqTelemetry.attach(false)

      # Will not emit events
      Req.get!(req, url: "https://example.org")

      # Override to emit events
      Req.get!(req, url: "https://example.org", telemetry: true)

      # Override to emit only adapter events
      Req.get!(req, url: "https://example.org", telemetry: [adapter: true])

  """
  @spec attach(Req.Request.t(), options) :: Req.Request.t()
  def attach(%Req.Request{} = req, opts \\ @default_opts) do
    default_opts =
      case normalize_opts(opts) do
        {:ok, opts} -> opts
        {:error, opts} -> options_error!(opts)
      end

    req
    |> Req.Request.register_options([:telemetry])
    |> Req.Request.merge_options(telemetry: default_opts)
    # Pipeline events occur at start of request and end of response/error
    |> Req.Request.prepend_request_steps(pipeline_start: &emit_start(&1, :pipeline))
    |> Req.Request.append_response_steps(pipeline_stop: &emit_stop(&1, :pipeline))
    |> Req.Request.append_error_steps(pipeline_error: &emit_error(&1, :pipeline))
    # Adapter events occur at end of request and start of response/error
    |> Req.Request.append_request_steps(adapter_start: &emit_start(&1, :adapter))
    |> Req.Request.prepend_response_steps(adapter_stop: &emit_stop(&1, :adapter))
    |> Req.Request.prepend_error_steps(adapter_error: &emit_error(&1, :adapter))
    # Prepend setup at the end to ensure it is run first
    |> Req.Request.prepend_request_steps(telemetry_setup: &telemetry_setup/1)
  end

  @doc """
  Returns a list of all events emitted by `ReqTelemetry`.
  """
  def events, do: @events

  @doc """
  Basic telemetry event handler that logs `ReqTelemetry` events.

  By default, only the following events are logged. This can be configured by passing in a
  different list of events.

    * `[:req, :request, :adapter, :start]`
    * `[:req, :request, :adapter, :stop]`
    * `[:req, :request, :pipeline, :error]`

  Example of a successful request:

      Req:479128347 - GET https://example.org (adapter)
      Req:479128347 - 200 in 403ms (adapter)

  """
  @default_logged_events [
    [:req, :request, :adapter, :start],
    [:req, :request, :adapter, :stop],
    [:req, :request, :pipeline, :error]
  ]
  @spec attach_default_logger() :: :ok | {:error, :already_exists}
  def attach_default_logger(events \\ @default_logged_events) do
    unless events -- @events == [] do
      raise ArgumentError, """
      cannot attach ReqTelemetry logger to unknown events: #{inspect(events -- @events)}
      """
    end

    :telemetry.attach_many(
      "req-telemetry-handler",
      events,
      &ReqTelemetry.Logger.handle_event/4,
      nil
    )
  end

  @doc false
  def telemetry_setup(%Req.Request{options: options} = req) do
    req = Req.Request.put_private(req, :telemetry, %{ref: make_ref()})

    case options |> Map.get(:telemetry, true) |> normalize_opts() do
      {:ok, opts} ->
        Req.Request.merge_options(req, telemetry: opts)

      {:error, opts} ->
        Logger.warn(options_error(opts) <> "\nEvents will not be emitted.")
        Req.Request.merge_options(req, telemetry: @no_emit_opts)
    end
  end

  @doc false
  def emit_start(req, event) do
    if emit?(req, event) do
      %{ref: ref} = Req.Request.get_private(req, :telemetry)
      %{url: url, method: method, headers: headers} = req

      :telemetry.execute(
        [:req, :request, event, :start],
        %{time: System.system_time()},
        %{ref: ref, url: url, method: method, headers: headers}
      )

      private = Req.Request.get_private(req, :telemetry, %{})
      Req.Request.put_private(req, :telemetry, Map.put(private, event, monotonic_time()))
    else
      req
    end
  end

  @doc false
  def emit_stop({req, resp}, event) do
    if emit?(req, event) do
      %{ref: ref} = Req.Request.get_private(req, :telemetry)
      %{url: url, method: method} = req
      %{status: status, headers: headers} = resp

      :telemetry.execute(
        [:req, :request, event, :stop],
        %{duration: duration(req, event)},
        %{ref: ref, url: url, method: method, status: status, resp_headers: headers}
      )
    end

    {req, resp}
  end

  @doc false
  def emit_error({req, exception}, event) do
    if emit?(req, event) do
      %{ref: ref} = Req.Request.get_private(req, :telemetry)
      %{url: url, method: method, headers: headers} = req

      :telemetry.execute(
        [:req, :request, event, :error],
        %{duration: duration(req, event)},
        %{ref: ref, url: url, method: method, headers: headers, error: exception}
      )
    end

    {req, exception}
  end

  defp normalize_opts(true), do: {:ok, @default_opts}
  defp normalize_opts(false), do: {:ok, @no_emit_opts}

  defp normalize_opts(opts) when is_list(opts) do
    if Keyword.keyword?(opts) do
      normalize_opts(Map.new(opts))
    else
      {:error, opts}
    end
  end

  defp normalize_opts(opts) when is_map(opts) do
    case Map.keys(opts) -- [:adapter, :pipeline] do
      [] -> {:ok, Map.merge(@default_opts, opts)}
      _ -> {:error, opts}
    end
  end

  defp normalize_opts(opts), do: {:error, opts}

  defp options_error!(opts) do
    raise ArgumentError, options_error(opts)
  end

  defp options_error(opts) do
    """
    Invalid `ReqTelemetry` options. Valid options must be a boolean
    or a keyword list/map containing `:adapter` and/or `:pipeline` keys.

    Got: #{inspect(opts)}
    """
  end

  defp emit?(%{options: %{telemetry: opts}}, event), do: opts[event]

  defp duration(req, event) do
    req
    |> Req.Request.get_private(:telemetry, %{})
    |> Map.get(event)
    |> case do
      nil -> nil
      start -> monotonic_time() - start
    end
  end

  defp monotonic_time, do: System.monotonic_time(:microsecond)
end
