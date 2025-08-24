alias Dbservice.Repo
alias Dbservice.Products.Product

IO.puts("  → Seeding products...")

# Product data based on the examples from dump.sql
products_data = [
  %{
    name: "TP-Async",
    mode: "Online",
    model: "Asynchronous",
    tech_modules: nil,
    type: nil,
    led_by: "AF",
    goal: nil,
    code: "TP-Async"
  },
  %{
    name: "FN-Async",
    mode: "Online",
    model: "Asynchronous",
    tech_modules: nil,
    type: nil,
    led_by: "AF",
    goal: nil,
    code: "FN-Async"
  },
  %{
    name: "TT-Sync",
    mode: "Offline",
    model: "Synchronous",
    tech_modules: nil,
    type: nil,
    led_by: "AF",
    goal: nil,
    code: "TT-Sync"
  },
  %{
    name: "TP-Broadcast",
    mode: "Broadcast",
    model: "Synchronous",
    tech_modules: nil,
    type: nil,
    led_by: "AF",
    goal: nil,
    code: "TP-Broadcast"
  },
  %{
    name: "Gurukul-Async",
    mode: "Online",
    model: "Asynchronous",
    tech_modules: nil,
    type: nil,
    led_by: "AF",
    goal: nil,
    code: "Gurukul-Async"
  },
  %{
    name: "TP-Sync",
    mode: "Online",
    model: "Synchronous",
    tech_modules: nil,
    type: nil,
    led_by: "AF",
    goal: nil,
    code: "TP-Sync"
  },
  %{
    name: "TP-Phy",
    mode: "Offline",
    model: "Synchronous",
    tech_modules: nil,
    type: nil,
    led_by: "AF",
    goal: "40% of active participants clear JEE Main or equivalent",
    code: "TP-Phy"
  }
]

products_created = for product_attrs <- products_data do
  unless Repo.get_by(Product, code: product_attrs.code) do
    %Product{}
    |> Product.changeset(product_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

actual_products_created = Enum.count(products_created, &(&1 != nil))
IO.puts("    ✅ Products seeded (#{length(products_data)} total, #{actual_products_created} new products)")
