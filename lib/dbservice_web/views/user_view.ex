defmodule DbserviceWeb.UserView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserView
  alias DbserviceWeb.SessionView

  def render("index.json", %{user: user}) do
    render_many(user, UserView, "user.json")
  end

  def render("show.json", %{user: user}) do
    render_one(user, UserView, "user.json")
  end

  def render("show_user_with_compact_fields.json", %{user: user}) do
    render_one(user, UserView, "user_with_compact_fields.json")
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
      region: user.region,
      pincode: user.pincode,
      role: user.role,
      whatsapp_phone: user.whatsapp_phone,
      date_of_birth: user.date_of_birth,
      country: user.country
    }
  end

  def render("user_with_compact_fields.json", %{user: user}) do
    %{
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      gender: user.gender,
      city: user.city,
      district: user.district,
      state: user.state,
      region: user.region,
      pincode: user.pincode,
      whatsapp_phone: user.whatsapp_phone,
      date_of_birth: user.date_of_birth,
      country: user.country
    }
  end

  def render("user_sessions.json", %{session: session}) do
    render_many(session, SessionView, "session.json")
  end
end
