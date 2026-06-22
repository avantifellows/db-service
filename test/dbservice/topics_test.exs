defmodule Dbservice.TopicsTest do
  use Dbservice.DataCase

  alias Dbservice.Topics
  alias Dbservice.Topics.Topic

  describe "topic code uniqueness" do
    test "rejects creating a topic with a code that already exists" do
      assert {:ok, %Topic{}} = Topics.create_topic(%{"code" => "TP-DUP"})

      assert {:error, changeset} = Topics.create_topic(%{"code" => "TP-DUP"})
      assert "has already been taken" in errors_on(changeset).code
    end

    test "allows multiple topics without a code" do
      assert {:ok, %Topic{}} = Topics.create_topic(%{"name" => [%{"topic" => "A"}]})
      assert {:ok, %Topic{}} = Topics.create_topic(%{"name" => [%{"topic" => "B"}]})
    end

    test "allows updating a topic without changing its code" do
      {:ok, topic} = Topics.create_topic(%{"code" => "TP-1"})

      assert {:ok, %Topic{}} =
               Topics.update_topic(topic, %{"name" => [%{"topic" => "Renamed"}]})
    end

    test "rejects updating a topic to a code used by another topic" do
      {:ok, _first} = Topics.create_topic(%{"code" => "TP-A"})
      {:ok, second} = Topics.create_topic(%{"code" => "TP-B"})

      assert {:error, changeset} = Topics.update_topic(second, %{"code" => "TP-A"})
      assert "has already been taken" in errors_on(changeset).code
    end
  end
end
