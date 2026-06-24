defmodule Dbservice.TopicsTest do
  use Dbservice.DataCase

  alias Dbservice.Topics
  alias Dbservice.Topics.Topic
  alias Dbservice.Repo

  describe "topic code uniqueness" do
    test "rejects creating a topic with a code that already exists" do
      assert {:ok, %Topic{}} = Topics.create_topic(%{"code" => "TP-DUP"})

      assert {:error, changeset} = Topics.create_topic(%{"code" => "TP-DUP"})
      assert "has already been taken" in errors_on(changeset).code
    end

    test "rejects creating a topic without a code" do
      assert {:error, changeset} = Topics.create_topic(%{"name" => [%{"topic" => "A"}]})
      assert "can't be blank" in errors_on(changeset).code
    end

    test "allows updating an existing topic that has no code (legacy row)" do
      # Simulate a pre-existing row that was created before code was required.
      legacy = Repo.insert!(%Topic{name: [%{"topic" => "Legacy"}]})

      assert {:ok, %Topic{}} =
               Topics.update_topic(legacy, %{"name" => [%{"topic" => "Renamed"}]})
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
