defmodule ReqTelemetry.Logger do
  @moduledoc false

  require Logger

  def handle_event(
        [_, _, event, :start],
        _measurements,
        %{ref: ref, url: url, method: method},
        _config
      ) do
    log(:info, [prefix(ref), format_method(method), " ", to_string(url), suffix(event)])
  end

  def handle_event(
        [_, _, event, :stop],
        %{duration: duration},
        %{ref: ref, status: status},
        _config
      ) do
    log(:info, [prefix(ref), to_string(status), " in ", format_duration(duration), suffix(event)])
  end

  def handle_event(
        [_, _, event, :error],
        %{duration: duration},
        %{ref: ref, error: error},
        _config
      ) do
    log(:error, [
      prefix(ref),
      "ERROR in ",
      format_duration(duration),
      suffix(event),
      "\n",
      inspect(error)
    ])
  end

  defp log(level, iodata) do
    Logger.log(level, IO.iodata_to_binary(iodata))
  end

  defp prefix(ref) do
    ["Req:", format_ref(ref), " - "]
  end

  defp suffix(event) do
    [" (", to_string(event), ")"]
  end

  defp format_ref(ref) do
    ref
    |> :erlang.phash2()
    |> to_string()
  end

  defp format_duration(native_time) do
    [to_string(System.convert_time_unit(native_time, :native, :millisecond)), "ms"]
  end

  defp format_method(method), do: method |> to_string() |> String.upcase()
end
