defmodule Peluquero do
  @moduledoc """
  Application handler for the `Peluquero` application.
  """

  use Application

  require Logger

  @joiner "/"
  @consul Application.get_env(:peluquero, :consul, "configuration/macroservices/peluquero")

  @doc false
  def start(type, args) do
    import Supervisor.Spec, warn: false

    Logger.warn(fn -> "✂ Peluquero started with #{inspect {type, args}}" end)

    children = [
      worker(Peluquero.Actor, [[]]),
      worker(Peluquero.Rabbit, [[opts: [], consul: @consul]]),
    ]

    opts = [strategy: :one_for_one, name: Peluquero.Supervisor]
    Supervisor.start_link(children, opts)
  end

  ##############################################################################

  def consul(root, path) when is_nil(root), do: consul(@consul, path)
  def consul(root, path) when is_nil(path), do: consul(root, "")
  def consul(root, path) when is_list(path), do: consul(root, Enum.join(path, @joiner))
  def consul(root, path) when is_binary(path) do
    path = [root, path]
           |> Enum.join(@joiner)
           |> String.trim_trailing(@joiner)
    size = String.length(path)
    case Consul.Kv.keys!(path) do
      %HTTPoison.Response{body: keys} when is_list(keys) ->
        keys
        |> Enum.map(fn
          <<_ :: binary-size(size), @joiner :: binary, key :: binary>> -> key
        end)
        |> Enum.filter(& &1 != "")
        |> Enum.map(fn key ->
                      case Peluquero.Utils.consul_key_type(key) do
                        {:nested, _, _} -> nil
                        {:plain, :bag, rest} ->
                          {String.to_atom(rest), consul(path, key)}
                        {:plain, :item, _} ->
                          with %HTTPoison.Response{body: [%{"Value" => value}]} <- Consul.Kv.fetch!("#{path}#{@joiner}#{key}"),
                            do: {String.to_atom(key), value}
                      end
        end)
        |> Enum.filter(& not is_nil(&1))
        |> Enum.into([])
      _ -> []
    end
  end
end
