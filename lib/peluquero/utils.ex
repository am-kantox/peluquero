defmodule Peluquero.Utils do
  @moduledoc "Plain utilities for the project"

  require Logger

  @joiner "/"
  @max_match 20

  @doc ~S"""
    Quick check for the consul key.

    ## Examples
        iex> Peluquero.Utils.consul_key_type("a/b/c/")
        {:nested, :bag, "a"}
        iex> Peluquero.Utils.consul_key_type("a/b/c")
        {:nested, :item, "a"}
        iex> Peluquero.Utils.consul_key_type("a/")
        {:plain, :bag, "a"}
        iex> Peluquero.Utils.consul_key_type("a")
        {:plain, :item, "a"}
  """
  @spec consul_key_type(String.t()) :: {:plain | :nested, :bag | :item, String.t()}
  def consul_key_type(key)

  0..@max_match
  |> Enum.each(fn n ->
       @n n
       def consul_key_type(<<
             key::binary-size(unquote(@n)),
             unquote(@joiner)::binary,
             rest::binary
           >>) do
         case String.reverse(rest) do
           "" -> {:plain, :bag, key}
           <<@joiner::binary, _::binary>> -> {:nested, :bag, key}
           _ -> {:nested, :item, key}
         end
       end

       def consul_key_type(<<rest::binary-size(unquote(@n + 1))>>), do: {:plain, :item, rest}
     end)

  def consul_key_type(key) when is_binary(key) do
    {type, rest} =
      case String.reverse(key) do
        <<@joiner::binary, rest::binary>> -> {:bag, String.reverse(rest)}
        _ -> {:item, key}
      end

    {if(String.contains?(rest, @joiner), do: :nested, else: :plain), type, rest}
  end

  ##############################################################################

  def safe(value) when is_nil(value), do: ""
  def safe(false), do: "false"
  def safe(true), do: "true"
  def safe(value) when is_binary(value), do: value
  def safe(value) when is_integer(value), do: Integer.to_string(value)
  def safe(value) when is_float(value), do: Float.to_string(value)
  def safe(value) when is_atom(value), do: Atom.to_string(value)
  def safe(value), do: JSON.encode!(value)

  ##############################################################################

  def consul(root, path) when is_list(path), do: consul(root, Enum.join(path, @joiner))
  def consul(root, path) when is_atom(path), do: consul(root, Atom.to_string(path))

  def consul(root, path) when is_binary(path) do
    path =
      [root, path]
      |> Enum.join(@joiner)
      |> String.trim_trailing(@joiner)

    size = String.length(path)

    case Consul.Kv.keys(path) do
      {:ok, %HTTPoison.Response{body: keys}} when is_list(keys) ->
        keys
        |> Enum.map(fn <<_::binary-size(size), @joiner::binary, key::binary>> -> key end)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(fn key ->
             case Peluquero.Utils.consul_key_type(key) do
               {:nested, _, _} ->
                 nil

               {:plain, :bag, rest} ->
                 {String.to_atom(rest), consul(path, key)}

               {:plain, :item, _} ->
                 with %HTTPoison.Response{body: [%{"Value" => value}]} <-
                        Consul.Kv.fetch!("#{path}#{@joiner}#{key}"),
                      do: {String.to_atom(key), value}
             end
           end)
        |> Enum.filter(&(not is_nil(&1)))
        |> Enum.into([])

      {:error, %HTTPoison.Error{id: _, reason: :econnrefused}} ->
        Logger.error("Connection to consul refused for path [#{path}], check settings")
        []

      any ->
        Logger.error("Unexpected error while connecting to consul: [#{inspect(any)}]")
        []
    end
  end

  ##############################################################################

  defmacro safe_method(name, id, param, do: block) do
    if Application.get_env(:peluquero, :safe_peinados, false) do
      quote do
        def unquote(name)(unquote(id) \\ nil, unquote(param)) do
          if child?(unquote(id)), do: unquote(block)
        end
      end
    else
      quote do
        def unquote(name)(unquote(id) \\ nil, unquote(param)), do: unquote(block)
      end
    end
  end

  defmacro safe_method(name, id, param1, param2, do: block) do
    if Application.get_env(:peluquero, :safe_peinados, false) do
      quote do
        def unquote(name)(unquote(id) \\ nil, unquote(param1), unquote(param2)) do
          if child?(unquote(id)), do: unquote(block)
        end
      end
    else
      quote do
        def unquote(name)(unquote(id) \\ nil, unquote(param1), unquote(param2)),
          do: unquote(block)
      end
    end
  end
end
