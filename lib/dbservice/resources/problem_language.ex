defmodule Dbservice.Resources.ProblemLanguage do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Resources.Paragraph
  alias Dbservice.Resources.Resource
  alias Dbservice.Resources.ProblemText
  alias Dbservice.Languages.Language

  schema "problem_lang" do
    field(:meta_data, :map)
    # Plain-text form of meta_data["text"] (HTML stripped, LaTeX kept) used for
    # trigram similarity search. Derived automatically below — never set by
    # callers — so every writer keeps it in sync (issue #700).
    field(:question_plain_text, :string)
    # Plain-text form of meta_data["options"], joined into one string, used to
    # score answer options alongside the question in the same search (issue
    # #777). Derived automatically below on the same terms as
    # question_plain_text - never set by callers.
    field(:options_plain_text, :string)
    belongs_to(:paragraph, Paragraph)
    belongs_to :resource, Resource, foreign_key: :res_id
    belongs_to :language, Language, foreign_key: :lang_id

    timestamps()
  end

  @doc false
  def changeset(problem_lang, attrs) do
    problem_lang
    |> cast(attrs, [
      :res_id,
      :lang_id,
      :meta_data,
      :paragraph_id
    ])
    |> validate_required([
      :res_id,
      :lang_id
    ])
    |> put_question_plain_text()
    |> put_options_plain_text()
  end

  # Keeps question_plain_text derived from meta_data["text"] on every write,
  # using the shared normalization so stored candidates and search queries are
  # scored on identical text. Idempotent: on updates that don't touch meta_data,
  # get_field returns the existing value and re-derives the same result.
  defp put_question_plain_text(changeset) do
    text =
      case get_field(changeset, :meta_data) do
        %{} = meta -> meta["text"] || meta[:text]
        _ -> nil
      end

    put_change(changeset, :question_plain_text, ProblemText.to_plain_text(text))
  end

  # The options counterpart of put_question_plain_text/1, with the same
  # derived-on-every-write contract so a problem's stored options and the ones a
  # search sends are normalized by the same code.
  defp put_options_plain_text(changeset) do
    options =
      case get_field(changeset, :meta_data) do
        %{} = meta -> meta["options"] || meta[:options]
        _ -> nil
      end

    put_change(changeset, :options_plain_text, ProblemText.options_to_plain_text(options))
  end
end
