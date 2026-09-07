defmodule Dbservice.Resources.ProblemTextTest do
  use ExUnit.Case, async: true

  alias Dbservice.Resources.ProblemText

  describe "to_plain_text/1" do
    test "strips HTML tags" do
      assert ProblemText.to_plain_text("<div>Hello <b>world</b></div>") == "Hello world"
    end

    test "inserts a space at block boundaries so adjacent words don't fuse" do
      assert ProblemText.to_plain_text("<div>A</div><div>B</div>") == "A B"
    end

    test "keeps LaTeX/math intact" do
      html = "<div>Value of \\(E_0 \\sin(3y+4z)\\hat{i}\\) here</div>"
      assert ProblemText.to_plain_text(html) == "Value of \\(E_0 \\sin(3y+4z)\\hat{i}\\) here"
    end

    test "collapses whitespace and trims" do
      assert ProblemText.to_plain_text("  <div>a   b\n\tc</div>  ") == "a b c"
    end

    test "handles plain text without tags" do
      assert ProblemText.to_plain_text("just text") == "just text"
    end

    test "handles malformed markup by falling back to the raw text" do
      assert ProblemText.to_plain_text("<div>unclosed") == "unclosed"
    end

    test "returns empty string for nil and non-binaries" do
      assert ProblemText.to_plain_text(nil) == ""
      assert ProblemText.to_plain_text(%{"text" => "x"}) == ""
      assert ProblemText.to_plain_text(123) == ""
    end
  end
end
