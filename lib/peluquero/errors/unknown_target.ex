defmodule Peluquero.Errors.UnknownTarget do
  defexception ~w|target message existing reason|a

  @existing :peluquero
            |> Application.get_env(:peluquerias, [])
            |> Keyword.keys()

  def exception(target: target, reason: reason) do
    target =
      case String.Chars.impl_for(target) do
        nil -> inspect(target)
        _ -> target
      end

    message = "Target #{target} is unknown. Reason: #{reason}."

    %Peluquero.Errors.UnknownTarget{
      message: message,
      target: target,
      existing: @existing,
      reason: reason
    }
  end
end
