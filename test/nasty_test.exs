defmodule NastyTest do
  use ExUnit.Case
  doctest Nasty

  test "returns version info" do
    assert Nasty.hello() == {:ok, "Nasty v0.1.0 - Early Development"}
  end

  test "parse requires language parameter" do
    assert Nasty.parse("Hello world.") == {:error, :language_required}
  end

  test "parse returns error for unregistered language" do
    assert Nasty.parse("Hello world.", language: :fr) == {:error, {:language_not_registered, :fr}}
  end

  test "parse works with registered English language" do
    assert {:ok, %Nasty.AST.Document{}} = Nasty.parse("Hello world.", language: :en)
  end
end
