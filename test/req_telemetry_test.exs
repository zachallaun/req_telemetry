defmodule ReqTelemetryTest do
  use ExUnit.Case
  doctest ReqTelemetry

  describe "attach/2" do
    test "merges default :telemetry options when none are specified" do
      req = Req.new() |> ReqTelemetry.attach()
      assert {:ok, %{adapter: true, pipeline: true}} = ReqTelemetry.fetch_options(req)
    end

    test "merges default :telemetry options when some are specified" do
      req = Req.new() |> ReqTelemetry.attach(pipeline: false)
      assert {:ok, %{adapter: true, pipeline: false}} = ReqTelemetry.fetch_options(req)

      req = Req.new() |> ReqTelemetry.attach(adapter: false)
      assert {:ok, %{adapter: false, pipeline: true}} = ReqTelemetry.fetch_options(req)

      req = Req.new() |> ReqTelemetry.attach(adapter: false, pipeline: false)
      assert {:ok, %{adapter: false, pipeline: false}} = ReqTelemetry.fetch_options(req)
    end

    test "accepts boolean options" do
      req = Req.new() |> ReqTelemetry.attach(true)
      assert {:ok, %{adapter: true, pipeline: true}} = ReqTelemetry.fetch_options(req)

      req = Req.new() |> ReqTelemetry.attach(false)
      assert {:ok, %{adapter: false, pipeline: false}} = ReqTelemetry.fetch_options(req)
    end

    test "raises if given invalid options" do
      invalid = [
        [{"adapter", false}],
        [unknown: true],
        [adapter: false, unknown: true],
        %{"adapter" => false},
        :unknown
      ]

      for opts <- invalid do
        assert_raise ArgumentError, fn -> Req.new() |> ReqTelemetry.attach(opts) end
      end
    end
  end

  describe "attach_default_logger/1" do
    test "raises if given unknown events" do
      assert_raise ArgumentError, fn ->
        ReqTelemetry.attach_default_logger([:unknown, :event])
      end
    end
  end

  describe "telemetry events" do
    @default_url "https://example.org"
    @default_status 200
    @default_headers [{"content-type", "application/json"}]
    @default_body ""

    defmodule Handler do
      def handle_event(event, measurements, metadata, _config) do
        send(self(), {:telemetry, event, measurements, metadata})
      end
    end

    setup context do
      :telemetry.attach_many(
        "#{context[:test]}",
        ReqTelemetry.events(),
        &Handler.handle_event/4,
        nil
      )

      mock_req = fn resp_attrs ->
        Req.new(
          url: @default_url,
          adapter: fn request ->
            response = %Req.Response{
              status: @default_status,
              headers: @default_headers,
              body: @default_body
            }

            {request, Map.merge(response, resp_attrs)}
          end
        )
      end

      %{mock_req: mock_req}
    end

    test "are emitted at the start and end of a request", %{mock_req: req} do
      req.(%{}) |> ReqTelemetry.attach() |> Req.get!()

      assert_received {:telemetry, [:req, :request, :pipeline, :start], _, _}
      assert_received {:telemetry, [:req, :request, :adapter, :start], _, _}
      assert_received {:telemetry, [:req, :request, :adapter, :stop], _, _}
      assert_received {:telemetry, [:req, :request, :pipeline, :stop], _, _}
    end

    test "can be excluded with options to attach/1", %{mock_req: req} do
      req.(%{}) |> ReqTelemetry.attach(false) |> Req.get!()
      refute_received {:telemetry, [:req, :request, _, _], _, _}

      req.(%{}) |> ReqTelemetry.attach(pipeline: false) |> Req.get!()
      assert_received {:telemetry, [:req, :request, :adapter, _], _, _}
      refute_received {:telemetry, [:req, :request, :pipeline, _], _, _}
    end

    test "can be overriden with options passed to the request", %{mock_req: req} do
      req.(%{}) |> ReqTelemetry.attach() |> Req.get!(telemetry: false)
      refute_received {:telemetry, [:req, :request, _, _], _, _}

      req.(%{}) |> ReqTelemetry.attach() |> Req.get!(telemetry: [adapter: false])
      assert_received {:telemetry, [:req, :request, :pipeline, _], _, _}
      refute_received {:telemetry, [:req, :request, :adapter, _], _, _}
    end

    test "excluded in attach/1 can be overriden", %{mock_req: req} do
      req.(%{}) |> ReqTelemetry.attach(false) |> Req.get!(telemetry: [adapter: true])
      assert_received {:telemetry, [:req, :request, :adapter, _], _, _}
      refute_received {:telemetry, [:req, :request, :pipeline, _], _, _}
    end
  end
end
