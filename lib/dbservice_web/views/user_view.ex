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
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      gender: user.gender,
      address: user.address,
      city: user.city,
      district: user.district,
      state: user.state,
      pincode: user.pincode,
      role: user.role,
      whatsapp_phone: user.whatsapp_phone,
      date_of_birth: user.date_of_birth,
      country: user.country
    }
  end
end
