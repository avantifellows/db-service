defmodule DbserviceWeb.DemographicProfileJSON do
  def index(%{demographic_profile: demographic_profiles}) do
    for(dp <- demographic_profiles, do: render(dp))
  end

  def show(%{demographic_profile: demographic_profile}) do
    render(demographic_profile)
  end

  def render(demographic_profile) do
    %{
      id: demographic_profile.id,
      category_id: demographic_profile.category_id,
      gender: demographic_profile.gender,
      caste: demographic_profile.caste,
      physically_handicapped: demographic_profile.physically_handicapped,
      family_income: demographic_profile.family_income,
      religion: demographic_profile.religion,
      defence_ward: demographic_profile.defence_ward,
      nationality: demographic_profile.nationality,
      ews_ward: demographic_profile.ews_ward,
      language: demographic_profile.language,
      urban_rural: demographic_profile.urban_rural,
      region: demographic_profile.region
    }
  end
end
