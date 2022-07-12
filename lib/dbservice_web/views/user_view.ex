defmodule DbserviceWeb.UserView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserView

  def render("index.json", %{user: user}) do
    render_many(user, UserView, "user.json")
  end

  def render("show.json", %{user: user}) do
    render_one(user, UserView, "user.json")
  end

  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      phone: user.phone,
      gender: user.gender,
      address: user.address,
      city: user.city,
      district: user.district,
      state: user.state,
      pincode: user.pincode,
      role: user.role
    }
  end
end
