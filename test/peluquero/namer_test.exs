defmodule Peluquero.Namer.Test do
  @moduledoc false

  use ExUnit.Case
  use Peluquero.Tester

  doctest Peluquero.Namer

  test "fqname/2" do
    Code.eval_string """
    defmodule Sample do
      use Peluquero.Namer

      def test(name), do: fqname(name)
      def test(mod, name), do: fqname(mod, name)
    end
    """
    assert Sample.test(nil) == Sample
    assert Sample.test(:a) == Sample.A
    assert Sample.test("a") == Sample.A
    assert Sample.test("a.b.c") == Sample.A.B.C
    assert Sample.test(A.B.C) == Sample.A.B.C
    assert Sample.test(Peluquero.Namer.Test, :a) == Peluquero.Namer.Test.A
    assert Sample.test(Peluquero.Namer, Peluquero.Namer.Test) == Peluquero.Namer.Test
  after
    purge Sample
  end
end
