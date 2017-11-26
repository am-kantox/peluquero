defmodule Peluquero.Namer do
  @moduledoc false
  defmacro __using__(opts) do
    quote bind_quoted: [prefix: opts[:module]] do
      @module_prefix prefix

      @spec fqname(Atom.t(), String.t() | Atom.t() | List.t() | nil) :: Atom.t()
      def fqname(module \\ @module_prefix || __MODULE__, suffix)
      def fqname(module, nil), do: module

      def fqname(module, suffix) when is_atom(suffix),
        do: fqname(module, suffix |> Atom.to_string() |> String.trim_leading("Elixir."))

      def fqname(module, suffix) when is_list(suffix), do: fqname(module, suffix[:name])

      def fqname(module, suffix) when is_binary(suffix) do
        to_trim =
          module
          |> Atom.to_string()
          |> String.trim_leading("Elixir.")
          |> Kernel.<>(".")

        modules =
          suffix
          |> String.trim_leading(to_trim)
          |> String.split(".")
          |> Enum.map(&String.capitalize/1)

        Module.concat([module | modules])
      end

      @spec fqparent(Atom.t() | String.t() | List.t()) :: Atom.t()
      def fqparent(name)

      def fqparent(name) when is_list(name) do
        with [_, suffix | h] <- :lists.reverse(name) do
          module =
            h
            |> :lists.reverse()
            |> Module.concat()

          fqname(module, suffix)
        end
      end

      def fqparent(name) when is_binary(name) do
        name
        |> String.split(".")
        |> fqparent()
      end

      def fqparent(name) when is_atom(name) do
        name
        |> Atom.to_string()
        |> fqparent()
      end
    end
  end
end
