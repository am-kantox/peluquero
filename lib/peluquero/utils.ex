defmodule Peluquero.Utils do
  @moduledoc "Plain utilities for the project"

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
  @spec consul_key_type(String.t) :: {(:plain | :nested), (:bag | :item)}
  def consul_key_type(key)

  0..@max_match |> Enum.each(fn n ->
    @n n
    def consul_key_type(<<key :: binary-size(unquote(@n)), unquote(@joiner) :: binary, rest :: binary>>) do
      case String.reverse(rest) do
        "" -> {:plain, :bag, key}
        <<@joiner :: binary, _ :: binary>> -> {:nested, :bag, key}
        _ -> {:nested, :item, key}
      end
    end
    def consul_key_type(<<rest :: binary-size(unquote(@n + 1))>>), do: {:plain, :item, rest}
  end)
  def consul_key_type(key) when is_binary(key) do
    {type, rest} = case String.reverse(key) do
                     <<@joiner :: binary, rest :: binary>> -> {:bag, String.reverse(rest)}
                     _ -> {:item, key}
                   end
    {(if String.contains?(rest, @joiner), do: :nested, else: :plain), type, rest}
  end

  ##############################################################################

  def safe(value) when is_nil(value), do: ""
  def safe(value) when is_binary(value), do: value
  def safe(value) when is_integer(value), do: Integer.to_string(value)
  def safe(value) when is_float(value), do: Float.to_string(value)
  def safe(value) when is_atom(value), do: Atom.to_string(value)
  def safe(value), do: JSON.encode!(value)
end
