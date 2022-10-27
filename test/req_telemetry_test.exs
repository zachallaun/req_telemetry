defmodule ReqTelemetryTest do
  use ExUnit.Case
  doctest ReqTelemetry

  describe "attach/2" do
    test "merges default :telemetry options when none are specified" do
      req = Req.new() |> ReqTelemetry.attach()
      assert %{telemetry: %{adapter: true, pipeline: true}} = req.options
    end

    test "merges default :telemetry options when some are specified" do
      req = Req.new() |> ReqTelemetry.attach(pipeline: false)
      assert %{telemetry: %{adapter: true, pipeline: false}} = req.options

      req = Req.new() |> ReqTelemetry.attach(adapter: false)
      assert %{telemetry: %{adapter: false, pipeline: true}} = req.options

      req = Req.new() |> ReqTelemetry.attach(adapter: false, pipeline: false)
      assert %{telemetry: %{adapter: false, pipeline: false}} = req.options
    end

    test "accepts boolean options" do
      req = Req.new() |> ReqTelemetry.attach(true)
      assert %{telemetry: %{adapter: true, pipeline: true}} = req.options

      req = Req.new() |> ReqTelemetry.attach(false)
      assert %{telemetry: %{adapter: false, pipeline: false}} = req.options
    end
  end
end
