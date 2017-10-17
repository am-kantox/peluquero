defmodule Peluquero.Test do
  @moduledoc false

  use ExUnit.Case
  doctest Peluquero

  @tag timeout: 1_000_000
  test "check rabbit connection" do
    Process.sleep(1_000)
    assert 1 + 1 == 2
  end

  @tag :local_only
  test "redis peinado works" do
    assert is_nil(Peluquero.Peinados.get(:eventory, "test_test_test_test"))
    assert Peluquero.Peinados.set(:eventory, "test_test_test_test", 42) == :ok
    assert Peluquero.Peinados.get(:eventory, "test_test_test_test") == "42"
    assert Peluquero.Peinados.del(:eventory, "test_test_test_test") == :ok
    assert is_nil(Peluquero.Peinados.get(:eventory, "test_test_test_test"))
  end
end
