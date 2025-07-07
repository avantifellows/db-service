defmodule DbserviceWeb.TestRuleView do
  use DbserviceWeb, :view
  alias DbserviceWeb.TestRuleView

  def render("index.json", %{test_rules: test_rules}) do
    render_many(test_rules, TestRuleView, "test_rule.json")
  end

  def render("show.json", %{test_rule: test_rule}) do
    render_one(test_rule, TestRuleView, "test_rule.json")
  end

  def render("test_rule.json", %{test_rule: test_rule}) do
    %{
      id: test_rule.id,
      exam_id: test_rule.exam_id,
      test_type: test_rule.test_type,
      config: test_rule.config
    }
  end
end
