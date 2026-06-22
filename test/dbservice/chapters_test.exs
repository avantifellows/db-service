defmodule Dbservice.ChaptersTest do
  use Dbservice.DataCase

  alias Dbservice.Chapters
  alias Dbservice.Chapters.Chapter

  describe "chapter code uniqueness" do
    test "rejects creating a chapter with a code that already exists" do
      assert {:ok, %Chapter{}} = Chapters.create_chapter(%{"code" => "CH-DUP"})

      assert {:error, changeset} = Chapters.create_chapter(%{"code" => "CH-DUP"})
      assert "has already been taken" in errors_on(changeset).code
    end

    test "allows multiple chapters without a code" do
      assert {:ok, %Chapter{}} = Chapters.create_chapter(%{"name" => [%{"chapter" => "A"}]})
      assert {:ok, %Chapter{}} = Chapters.create_chapter(%{"name" => [%{"chapter" => "B"}]})
    end

    test "allows updating a chapter without changing its code" do
      {:ok, chapter} = Chapters.create_chapter(%{"code" => "CH-1"})

      assert {:ok, %Chapter{}} =
               Chapters.update_chapter(chapter, %{"name" => [%{"chapter" => "Renamed"}]})
    end

    test "rejects updating a chapter to a code used by another chapter" do
      {:ok, _first} = Chapters.create_chapter(%{"code" => "CH-A"})
      {:ok, second} = Chapters.create_chapter(%{"code" => "CH-B"})

      assert {:error, changeset} = Chapters.update_chapter(second, %{"code" => "CH-A"})
      assert "has already been taken" in errors_on(changeset).code
    end
  end
end
