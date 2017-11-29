defmodule Peluquero.Peluqueria.Test do
  @moduledoc false

  use ExUnit.Case
  use Peluquero.Tester

  setup_all _context do
    [bucket: start_supervised(Peluquero.Test.Bucket)]
  end

  test "inexisting queue" do
    assert_raise(
      Peluquero.Errors.UnknownTarget,
      fn ->
        Peluquero.Peluqueria.publish!(:local, %{foo: 42})
      end)
  end

  test "shear!/2" do
    Peluquero.Peluqueria.publish!(:hairy, %{foo: 42})
    Process.sleep(500)
    IO.inspect Peluquero.Test.Bucket.state, label: "shear!: "
  end
end
