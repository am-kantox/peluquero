defmodule Peluquero.Peluqueria.Test do
  @moduledoc false

  use ExUnit.Case
  use Peluquero.Tester

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
    assert Enum.count(Supervisor.which_children(Peluquero.Peluqueria.Hairy)) == 2 + 2
    assert Enum.count(Supervisor.which_children(Peluquero.Peluqueria.Shaved)) == 2 + 5
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
    Process.sleep(500)
    assert Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "shear!/2", %{data: data} do
    Peluquero.Peluqueria.shear!(:hairy, data)
    Process.sleep(500)
    assert Enum.member?(Peluquero.Test.Bucket.state(), data)
  end

  test "scissors!/2", %{data: data} do
    Peluquero.Peluqueria.scissors!(:shaved, {Peluquero.Test.Bucket, :put})
    Peluquero.Peluqueria.shear!(:hairy, data)
    Process.sleep(500)
    assert Enum.count(Peluquero.Test.Bucket.state(), fn e -> e == data end) == 2
  end
end
