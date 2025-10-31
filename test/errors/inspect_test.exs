defmodule Triage.InspectTest do
  use ExUnit.Case

  defmodule Person do
    @moduledoc false

    defstruct [:id, :name, :age, :email, :role_id, :city, :country]
  end

  defmodule City do
    @moduledoc false

    defstruct [:id, :population, :name, :year_founded]
  end

  describe ".inspect" do
    test "basic values" do
      values = [
        # numbers
        1,
        963_256,
        -1_235_358,
        323.82354,
        -23.993523,
        # atoms
        :atom,
        :foo,
        :bar,
        :some_atom,
        :CamelCase,
        :"atom with spaces",
        # boolean
        true,
        false,
        # nil
        nil,
        # strings
        "",
        "hello",
        "hello world",
        "string with\nnewlines",
        "string with\ttabs",
        "string with \"quotes\"",
        "unicode: émojis 🎉 中文",
        <<>>,
        <<1, 2, 3>>,
        <<255, 254, 253>>,
        <<"hello">>,
        <<0::1, 1::1, 0::1>>,
        # lists
        [],
        [1, 2, 3],
        [:a, :b, :c],
        [1, :atom, "string", true],
        [[1, 2], [3, 4]],
        [1 | [2 | [3 | []]]],
        # tuples
        {},
        {1},
        {1, 2},
        {:ok, "success"},
        {:error, :not_found},
        {1, :atom, "string", [1, 2, 3]},
        {{1, 2}, {3, 4}},
        # maps
        %{},
        %{a: 1, b: "foo", c: :bar},
        %{"a" => 1, :b => "foo", 456 => :bar},
        # charlists
        ~c"",
        ~c"hello",
        ~c"hello world",
        [72, 101, 108, 108, 111]
      ]

      for value <- values do
        assert Triage.Inspect.inspect(value) == inspect(value)
      end
    end

    test "structs" do
      person = %Person{
        id: 1,
        name: "Alice Johnson",
        age: 30,
        email: "alice@example.com",
        role_id: 5,
        city: "San Francisco",
        country: "USA"
      }

      assert Triage.Inspect.inspect(person) ==
               ~s(#Triage.InspectTest.Person<id: 1, name: "Alice Johnson", role_id: 5, ...>)
    end

    test "struct with nil values" do
      person = %Person{id: 2, name: "Bob"}

      assert Triage.Inspect.inspect(person) ==
               ~s(#Triage.InspectTest.Person<id: 2, name: "Bob", role_id: nil, ...>)
    end

    test "empty struct" do
      person = %Person{}

      assert Triage.Inspect.inspect(person) ==
               "#Triage.InspectTest.Person<id: nil, name: nil, role_id: nil, ...>"
    end

    test "nested structs" do
      person = %Person{
        id: 1,
        name: "Alice Johnson",
        age: 30,
        email: "alice@example.com",
        role_id: 5,
        city: %City{
          id: 2,
          population: 1,
          name: "Alicetown",
          year_founded: 2025
        },
        country: "USA"
      }

      assert Triage.Inspect.inspect(person) ==
               "#Triage.InspectTest.Person<id: 1, name: \"Alice Johnson\", city: #Triage.InspectTest.City<id: 2, name: \"Alicetown\", ...>, role_id: 5, ...>"
    end
  end
end
