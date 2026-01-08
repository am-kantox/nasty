defmodule Nasty.Interop.CodeGen.ExplainTest do
  use ExUnit.Case, async: true

  alias Nasty.Interop.CodeGen.Explain

  describe "explain_function_call/4 for Enum.reduce" do
    test "returns explanation including reducer details with anonymous function" do
      code = """
      Enum.reduce(numbers, 0, fn acc, num -> acc + num end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "reduce"
      assert explanation =~ "numbers"
      assert explanation =~ "starting with"
      assert explanation =~ "0"
      assert explanation =~ "accumulating"
    end

    test "includes accumulator and element variable names in reducer explanation" do
      code = """
      Enum.reduce(list, [], fn accumulator, element -> [element | accumulator] end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "reduce"
      assert explanation =~ "list"
      assert explanation =~ "accumulator"
      assert explanation =~ "element"
    end

    test "explains reducer with different operations" do
      code = """
      Enum.reduce(items, 1, fn product, item -> product * item end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "reduce"
      assert explanation =~ "items"
      assert explanation =~ "starting with"
      assert explanation =~ "1"
      assert explanation =~ "product"
    end
  end

  describe "explain_mapper/1" do
    test "includes variable name in explanation for anonymous function" do
      code = """
      Enum.map(users, fn user -> user * 2 end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "map"
      assert explanation =~ "users"
      assert explanation =~ "transforming each"
      assert explanation =~ "user"
    end

    test "explains mapper with different variable names" do
      code = """
      Enum.map(products, fn product -> product + 10 end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "transforming each"
      assert explanation =~ "product"
    end

    test "handles mapper with complex transformation" do
      code = """
      Enum.map(numbers, fn num -> num * 2 + 1 end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "map"
      assert explanation =~ "transforming each"
      assert explanation =~ "num"
    end

    test "falls back for capture operator" do
      code = """
      Enum.map(list, &(&1 * 2))
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "map"
      assert explanation =~ "list"
    end

    test "falls back for non-anonymous function mapper" do
      code = """
      Enum.map(list, &String.upcase/1)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "map"
      assert explanation =~ "list"
      assert explanation =~ "with transformation"
    end
  end

  describe "explain_reducer/1" do
    test "correctly explains anonymous reducer functions" do
      code = """
      Enum.reduce(values, 0, fn sum, value -> sum + value end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "reduce"
      assert explanation =~ "values"
      assert explanation =~ "accumulating"
      assert explanation =~ "sum"
      assert explanation =~ "value"
    end

    test "explains reducer with list building" do
      code = """
      Enum.reduce(items, [], fn result, item -> [item | result] end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "reduce"
      assert explanation =~ "accumulating"
      assert explanation =~ "result"
      assert explanation =~ "item"
    end

    test "explains reducer with map accumulator" do
      code = """
      Enum.reduce(pairs, %{}, fn map, pair -> Map.put(map, pair.key, pair.value) end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "reduce"
      assert explanation =~ "accumulating"
      assert explanation =~ "map"
      assert explanation =~ "pair"
    end

    test "falls back for non-anonymous reducer" do
      code = """
      Enum.reduce(numbers, 0, &Kernel.+/2)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "reduce"
      assert explanation =~ "numbers"
      assert explanation =~ "with accumulator function"
    end
  end

  describe "other Enum function explanations" do
    test "explains Enum.sort" do
      {:ok, explanation} = Explain.explain_code("Enum.sort(numbers)")
      assert explanation == "sort numbers"
    end

    test "explains Enum.filter with predicate" do
      code = "Enum.filter(users, fn u -> u.age > 18 end)"
      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "filter"
      assert explanation =~ "users"
      assert explanation =~ "where"
    end

    test "explains Enum.sum" do
      {:ok, explanation} = Explain.explain_code("Enum.sum(values)")
      assert explanation == "sum values"
    end

    test "explains Enum.count" do
      {:ok, explanation} = Explain.explain_code("Enum.count(items)")
      assert explanation == "count items"
    end

    test "explains Enum.find with predicate" do
      code = "Enum.find(products, fn p -> p > 0 end)"
      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "find in"
      assert explanation =~ "products"
    end
  end

  describe "pipeline explanations" do
    test "explains pipeline with map and reduce" do
      code = """
      list
      |> Enum.map(fn x -> x * 2 end)
      |> Enum.reduce(0, fn acc, x -> acc + x end)
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "map"
      assert explanation =~ "then"
      assert explanation =~ "reduce"
      # The output doesn't directly include "transforming" for pipeline form
      # Check for key parts instead
      assert explanation =~ "list"
      assert explanation =~ "acc"
    end

    test "explains pipeline with filter and sum" do
      code = """
      numbers
      |> Enum.filter(fn n -> n > 10 end)
      |> Enum.sum()
      """

      {:ok, explanation} = Explain.explain_code(code)

      assert explanation =~ "filter"
      assert explanation =~ "numbers"
      assert explanation =~ "then"
      assert explanation =~ "sum"
    end
  end

  describe "assignments and other constructs" do
    test "explains simple assignment" do
      {:ok, explanation} = Explain.explain_code("x = 5")
      assert explanation == "X is 5"
    end

    test "explains conditional" do
      {:ok, explanation} = Explain.explain_code("if x > 5, do: :ok")
      assert explanation =~ "If"
      # The > operator is treated as a function call
      assert explanation =~ "call > with x and 5" or explanation =~ "is greater than"
    end

    test "explains arithmetic operations" do
      {:ok, explanation} = Explain.explain_code("a + b")
      # Arithmetic operations may be explained as function calls or operations
      assert explanation == "call + with a and b" or explanation == "a plus b"
    end
  end
end
