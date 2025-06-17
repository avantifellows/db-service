defmodule DbserviceWeb.UserJSON do
  alias DbserviceWeb.SessionJSON

  def index(%{user: user}) do
    for(u <- user, do: data(u))
  end

  def show(%{user: user}) do
    data(user)
  end

  def show_user_with_compact_fields(%{user: user}) do
    for(u <- user, do: user_with_compact_fields(u))
  end

  def data(user) do
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

  def user_with_compact_fields(user) do
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

  def user_sessions(%{session: session}) do
    for(s <- session, do: SessionJSON.data(s))
  end
end
