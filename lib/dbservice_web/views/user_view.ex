defmodule DbserviceWeb.UserView do
  use DbserviceWeb, :view
  
  def render("index.json", %{users: users}) do
    %{data: Enum.map(users, &user_json/1)}
  end

  def render("show.json", %{user: user}) do
    user_json(user)
  end

  def render("show_user_with_compact_fields.json", %{user: user}) do
    user_with_compact_fields_json(user)
  end

  def render("user_sessions.json", %{sessions: sessions}) do
    %{data: Enum.map(sessions, &session_json/1)}
  end

  def user_json(user) do
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

  def user_with_compact_fields_json(user) do
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

  def session_json(session) do
    %{:id => session.id,
     :name => session.name,
     :description => session.description,
     :status => session.status,
     :type => session.type,
     :started_at => session.started_at,
     :ended_at => session.ended_at,
     :session_form_schema_id => session.session_form_schema_id,
     :session_form_schema_name => session.session_form_schema_name,
     :is_active => session.is_active,
     :is_completed => session.is_completed,
     :created_by => session.created_by,
     :updated_by => session.updated_by,
     :updated_at => session.updated_at,
     :program_id => session.program_id,
     :program_name => session.program_name,
     :school_id => session.school_id,
     :school_name => session.school_name,
     :form_schema_id => session.form_schema_id,
     :form_schema_name => session.form_schema_name}
  end
end
