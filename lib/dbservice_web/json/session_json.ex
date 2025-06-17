defmodule DbserviceWeb.SessionJSON do
  def index(%{session: session}) do
    for(s <- session, do: data(s))
  end

  def show(%{session: session}) do
    data(session)
  end

  def data(session) do
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
      type: session.type,
      auth_type: session.auth_type,
      signup_form: session.signup_form,
      id_generation: session.id_generation,
      redirection: session.redirection,
      popup_form: session.popup_form,
      signup_form_id: session.signup_form_id,
      popup_form_id: session.popup_form_id,
      inserted_at: session.inserted_at,
      updated_at: session.updated_at
    }
  end
end
