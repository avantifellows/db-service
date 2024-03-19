defmodule Dbservice.Repo.Migrations.AlterSessionSchoolTables do
  use Ecto.Migration

  def change do
    rename table("school"), :type, to: :gender_type
    rename table("school"), :category, to: :af_school_category

    rename table("session"), :pop_up_form, to: :popup_form
    rename table("session"), :activate_signup, to: :signup_form
    rename table("session"), :form_schema_id, to: :signup_form_id
    
    alter table("session") do
      remove :number_of_fields_in_pop_form

      add :popup_form_id, references("form_schema")
    end
  end
end
