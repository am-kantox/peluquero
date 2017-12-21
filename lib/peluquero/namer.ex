defmodule Peluquero.Namer do
  @moduledoc false
  defmacro __using__(opts) do
    quote bind_quoted: [prefix: opts[:module]] do
      @module_prefix prefix

      @spec fqname(atom(), binary() | atom() | list() | nil) :: atom()
      @doc false
      def fqname(module \\ @module_prefix || __MODULE__, suffix)
      @doc false
      def fqname(module, nil), do: module
      @doc false
      def fqname(module, suffix) when is_atom(suffix),
        do: fqname(module, suffix |> Atom.to_string() |> String.trim_leading("Elixir."))
      @doc false
      def fqname(module, suffix) when is_list(suffix), do: fqname(module, suffix[:name])
      @doc false
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

      @spec fqparent(atom() | binary() | list()) :: atom()
      @doc false
      def fqparent(name)
      @doc false
      def fqparent(name) when is_list(name) do
        with [_, suffix | h] <- :lists.reverse(name) do
          module =
            h
            |> :lists.reverse()
            |> Module.concat()

          fqname(module, suffix)
        else
          [module] ->
            module
            |> fqname()
            |> fqparent()

          [] ->
            raise(Peluquero.Errors.UnknownTarget, target: [], reason: :empty)
        end
      end
      @doc false
      def fqparent(name) when is_binary(name) do
        name
        |> String.split(".")
        |> fqparent()
      end
      @doc false
      def fqparent(name) when is_atom(name) do
        name
        |> Atom.to_string()
        |> fqparent()
      end
    end
  end
end
