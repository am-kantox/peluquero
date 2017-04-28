defmodule Peluquero.Namer do
  @moduledoc false
  defmacro __using__(opts) do
    quote bind_quoted: [prefix: opts[:module]] do
      @module_prefix prefix

      @spec fqname(Atom.t, (String.t | Atom.t | List.t | nil)) :: Atom.t
      def fqname(module \\ @module_prefix || __MODULE__, suffix)
      def fqname(module, nil), do: module
      def fqname(module, suffix) when is_atom(suffix),
        do: fqname(module, suffix |> Atom.to_string() |> String.trim_leading("Elixir."))
      def fqname(module, suffix) when is_list(suffix),
        do: fqname(module, suffix[:name])
      def fqname(module, suffix) when is_binary(suffix) do
        modules = suffix
                  |> String.split(".")
                  |> Enum.map(&String.capitalize/1)
        Module.concat([module | modules])
      end
    end
  end
end
