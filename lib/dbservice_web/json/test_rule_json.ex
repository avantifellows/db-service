defmodule DbserviceWeb.TestRuleJSON do
  def index(%{test_rules: test_rules}) do
    for(tr <- test_rules, do: render(tr))
  end

  def show(%{test_rule: test_rule}) do
    render(test_rule)
  end

  defp render(test_rule) do
    %{
      id: test_rule.id,
      exam_id: test_rule.exam_id,
      test_type: test_rule.test_type,
      config: test_rule.config
    }
  end
end
