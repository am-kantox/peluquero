defmodule Peluquero.Peluqueria.Test do
  @moduledoc false

  use ExUnit.Case
  use Peluquero.Tester

  @rabbit_delay 50

  # import ExUnit.CaptureIO

  setup_all _context do
    [bucket: start_supervised(Peluquero.Test.Bucket)]

    # on_exit fn ->
    #   IO.inspect Peluquero.Test.Bucket.state(), label: "[⚑]"
    # end
  end

  setup context do
    [data: %{to_string(context.test) => 42}]
  end

  test "supervision tree" do
    assert Enum.count(Supervisor.which_children(Peluquera)) == 3
    # assert Enum.count(Supervisor.which_children(Peluquero.Peinados.Procurator)) == 0
    assert Enum.count(Supervisor.which_children(Peluquero.Peluqueria.Hairy)) == 2 + 5
    assert Enum.count(Supervisor.which_children(Peluquero.Peluqueria.Shaved)) == 2 + 1
  end

  test "inexisting queue", %{data: data} do
    assert_raise(
      Peluquero.Errors.UnknownTarget,
      fn ->
        Peluquero.Peluqueria.publish!(:local, data)
      end)
  end

  test "publish!/2", %{data: data} do
    Peluquero.Peluqueria.publish!(:hairy, data)
    Process.sleep(@rabbit_delay)
    assert Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "publish!/4", %{data: data} do
    Peluquero.Peluqueria.publish!(:hairy, "direct.test-queue", "test-fanout", data)
    Process.sleep(@rabbit_delay)
    assert not Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "shear!/2", %{data: data} do
    Peluquero.Peluqueria.shear!(:shaved, data)
    Process.sleep(@rabbit_delay)
    assert Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "shear!/4", %{data: data} do
    Peluquero.Peluqueria.shear!(:shaved, "direct.test-queue", "test-fanout", data)
    Process.sleep(@rabbit_delay)
    assert Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "comb!/2", %{data: data} do
    Peluquero.Peluqueria.comb!(:shaved, data)
    Process.sleep(@rabbit_delay)
    assert not Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "comb!/4", %{data: data} do
    Peluquero.Peluqueria.comb!(:shaved, "direct.test-queue", "test-fanout", data)
    Process.sleep(@rabbit_delay)
    assert not Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "scissors!/2", %{data: data} do
    Peluquero.Peluqueria.scissors!(:shaved, {Peluquero.Test.Bucket, :put})
    Peluquero.Peluqueria.shear!(:hairy, data)
    Process.sleep(@rabbit_delay)
    assert Enum.count(Peluquero.Test.Bucket.state(), fn e -> e == data end) >= 2
  end
end
