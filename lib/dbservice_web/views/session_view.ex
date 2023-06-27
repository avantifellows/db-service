defmodule DbserviceWeb.SessionView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SessionView

  def render("index.json", %{session: session}) do
    render_many(session, SessionView, "session.json")
  end

  def render("show.json", %{session: session}) do
    render_one(session, SessionView, "session.json")
  end

  def render("session.json", %{session: session}) do
    %{
      id: session.id,
      name: session.name,
      platform: session.platform,
      platform_link: session.platform_link,
      portal_link: session.portal_link,
      start_time: session.start_time,
      end_time: session.end_time,
      meta_data: session.meta_data,
      owner_id: session.owner_id,
      created_by_id: session.created_by_id,
      is_active: session.is_active,
      session_id: session.session_id,
      purpose: session.purpose,
      repeat_schedule: session.repeat_schedule,
      platform_id: session.platform_id,
      form_schema_id: session.form_schema_id,
      type: session.type,
      auth_type: session.auth_type,
      activate_signup: session.activate_signup,
      id_generation: session.id_generation,
      redirection: session.redirection,
      pop_up_form: session.pop_up_form,
      number_of_fields_in_pop_form: session.number_of_fields_in_pop_form
    }
  end
end
