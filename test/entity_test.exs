defmodule RazorpayEx.EntityTest do
  use ExUnit.Case, async: true

  alias RazorpayEx.{Entity, Payment}

  doctest RazorpayEx.Entity

  describe "build/2" do
    test "casts a payload into the matching resource struct" do
      entity = Entity.build("payment", %{"id" => "pay_1", "amount" => 500})

      assert %Payment{id: "pay_1", amount: 500} = entity
    end

    test "accepts string keys, atom keys and mixed keys" do
      assert %Payment{id: "pay_1", amount: 500} =
               Entity.build("payment", %{:id => "pay_1", "amount" => 500})
    end

    test "keeps fields the struct does not model in :extra" do
      entity =
        Entity.build("payment", %{
          "id" => "pay_1",
          "acquirer_data" => %{"rrn" => "123"},
          "upi" => %{"vpa" => "a@b"}
        })

      assert entity.id == "pay_1"
      assert entity.extra == %{"acquirer_data" => %{"rrn" => "123"}, "upi" => %{"vpa" => "a@b"}}
    end

    test "falls back to RazorpayEx.Entity for unsupported entity types" do
      entity = Entity.build("invoice", %{"id" => "inv_1", "amount" => 100})

      assert %Entity{id: "inv_1"} = entity
      assert entity.extra == %{"amount" => 100}
    end

    test "does not create atoms for unknown keys" do
      key = "brand_new_field_from_the_api"

      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end

      entity = Entity.build("payment", %{key => "value"})

      assert entity.extra[key] == "value"
      assert_raise ArgumentError, fn -> String.to_existing_atom(key) end
    end
  end

  describe "build/1" do
    test "picks the module from the entity field" do
      assert %Payment{id: "pay_1"} = Entity.build(%{"entity" => "payment", "id" => "pay_1"})
    end

    test "handles payloads without an entity field" do
      assert %Entity{id: "x"} = Entity.build(%{"id" => "x"})
    end
  end

  describe "module_for/1" do
    test "resolves implemented resources" do
      assert Entity.module_for("payment") == RazorpayEx.Payment
      assert Entity.module_for("order") == RazorpayEx.Order
      assert Entity.module_for("refund") == RazorpayEx.Refund
      assert Entity.module_for("customer") == RazorpayEx.Customer
    end

    test "falls back to the base entity for anything else" do
      assert Entity.module_for("collection") == RazorpayEx.Entity
      assert Entity.module_for("nonexistent_entity") == RazorpayEx.Entity
    end
  end

  test "to_map/1 drops nil values and an empty :extra" do
    assert Entity.to_map(%Entity{id: "x", entity: "payment"}) == %{id: "x", entity: "payment"}

    entity = %Entity{id: "x", entity: "payment", extra: %{"acquirer_data" => %{"rrn" => "1"}}}

    assert Entity.to_map(entity) == %{
             id: "x",
             entity: "payment",
             extra: %{"acquirer_data" => %{"rrn" => "1"}}
           }
  end
end
