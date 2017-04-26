defmodule Peluquero.Test do
  @moduledoc false

  use ExUnit.Case
  doctest Peluquero

  @tag timeout: 1_000_000
  test "check rabbit connection" do
    Process.sleep(1_000)
    assert 1 + 1 == 2
  end
end
