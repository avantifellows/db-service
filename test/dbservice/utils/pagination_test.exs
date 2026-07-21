defmodule Dbservice.Utils.PaginationTest do
  use ExUnit.Case, async: true

  alias Dbservice.Utils.Pagination

  describe "limit/1" do
    test "falls back to the default limit when the param is missing" do
      assert Pagination.limit(%{}) == Pagination.default_limit()
      assert Pagination.limit(%{"limit" => nil}) == Pagination.default_limit()
    end

    test "parses string and integer values" do
      assert Pagination.limit(%{"limit" => "50"}) == 50
      assert Pagination.limit(%{"limit" => 50}) == 50
    end

    test "clamps values above the max limit" do
      assert Pagination.limit(%{"limit" => "100000"}) == Pagination.max_limit()
      assert Pagination.limit(%{"limit" => 100_000}) == Pagination.max_limit()
    end

    test "clamps values below 1" do
      assert Pagination.limit(%{"limit" => "0"}) == 1
      assert Pagination.limit(%{"limit" => "-5"}) == 1
    end

    test "falls back to the default limit for unparseable values" do
      assert Pagination.limit(%{"limit" => "abc"}) == Pagination.default_limit()
      assert Pagination.limit(%{"limit" => "12abc"}) == Pagination.default_limit()
    end
  end

  describe "offset/1" do
    test "defaults to 0 when the param is missing" do
      assert Pagination.offset(%{}) == 0
      assert Pagination.offset(%{"offset" => nil}) == 0
    end

    test "parses string and integer values" do
      assert Pagination.offset(%{"offset" => "20"}) == 20
      assert Pagination.offset(%{"offset" => 20}) == 20
    end

    test "clamps negative and unparseable values to 0" do
      assert Pagination.offset(%{"offset" => "-10"}) == 0
      assert Pagination.offset(%{"offset" => "abc"}) == 0
    end
  end
end
