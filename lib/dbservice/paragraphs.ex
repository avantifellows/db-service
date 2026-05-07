defmodule Dbservice.Paragraphs do
  @moduledoc """
  The Paragraphs context.

  Paragraph text for reading-comprehension problems; linked from `problem_lang.paragraph_id`.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo
  alias Dbservice.Resources.Paragraph
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Resources.Resource

  @doc """
  Gets a single paragraph.

  Raises `Ecto.NoResultsError` if the paragraph does not exist.

  ## Examples

      iex> fetch_paragraph!(1)
      %Paragraph{}

      iex> fetch_paragraph!(999_999)
      ** (Ecto.NoResultsError)

  """
  def fetch_paragraph!(id), do: Repo.get!(Paragraph, id)

  @doc """
  Gets a paragraph and all `problem_lang` rows that reference it.

  Raises `Ecto.NoResultsError` if the paragraph does not exist.

  ## Examples

      iex> get_paragraph_with_problem_lang!(1)
      %{paragraph: %Paragraph{}, problem_lang: [%ProblemLanguage{}, ...]}

  """
  def get_paragraph_with_problem_lang!(id) do
    paragraph = Repo.get!(Paragraph, id)

    problem_lang =
      from(pl in ProblemLanguage, where: pl.paragraph_id == ^id, order_by: [asc: pl.id])
      |> Repo.all()

    %{paragraph: paragraph, problem_lang: problem_lang}
  end

  @doc """
  Creates a paragraph.

  ## Examples

      iex> create_paragraph(%{"body" => "Reading passage"})
      {:ok, %Paragraph{}}

      iex> create_paragraph(%{})
      {:error, %Ecto.Changeset{}}

  """
  def create_paragraph(attrs \\ %{}) do
    %Paragraph{}
    |> Paragraph.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a paragraph.

  ## Examples

      iex> update_paragraph(paragraph, %{"body" => "New text"})
      {:ok, %Paragraph{}}

      iex> update_paragraph(paragraph, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_paragraph(%Paragraph{} = paragraph, attrs) do
    paragraph
    |> Paragraph.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a paragraph.

  ## Examples

      iex> delete_paragraph(paragraph)
      {:ok, %Paragraph{}}

      iex> delete_paragraph(paragraph)
      {:error, %Ecto.Changeset{}}

  """
  def delete_paragraph(%Paragraph{} = paragraph), do: Repo.delete(paragraph)

  @doc """
  Returns true when the resource is a problem and its `subtype` (or override
  `params["subtype"]`) equals `"comprehension"` (case-insensitive). `subtype` is
  the standard problem categorisation alongside `mcq_single_answer`,
  `mcq_multiple_answer`, `numerical_answer`, etc.

  ## Examples

      iex> resource = %Resource{type: "problem", subtype: "comprehension"}
      iex> comprehension_problem?(resource, %{})
      true

      iex> resource = %Resource{type: "problem", subtype: "mcq_single_answer"}
      iex> comprehension_problem?(resource, %{"subtype" => "comprehension"})
      true

      iex> resource = %Resource{type: "problem", subtype: "mcq_single_answer"}
      iex> comprehension_problem?(resource, %{})
      false

  """
  def comprehension_problem?(%Resource{type: "problem"} = resource, params)
      when is_map(params) do
    comprehension_label?(params["subtype"] || resource.subtype)
  end

  def comprehension_problem?(_, _), do: false

  @doc """
  Returns the reading-passage body from `params["paragraph"]`, trimmed.
  Returns `nil` for non-map params, missing key, or blank string.

  ## Examples

      iex> paragraph_body_for_comprehension(%{"paragraph" => " Hello "})
      "Hello"

      iex> paragraph_body_for_comprehension(%{"paragraph" => ""})
      nil

      iex> paragraph_body_for_comprehension(:invalid)
      nil

  """
  def paragraph_body_for_comprehension(params) when is_map(params),
    do: nonempty_trimmed(params["paragraph"])

  def paragraph_body_for_comprehension(_), do: nil

  @doc """
  Builds attrs for inserting a `problem_lang` row when creating a resource.

  For comprehension problems, requires a `paragraph` body, creates a paragraph row,
  and sets `paragraph_id` on the `problem_lang` row. `meta_data` is forwarded as-is.

  ## Examples

      iex> resource = %Resource{id: 1, type: "problem", subtype: "comprehension"}
      iex> match?({:error, {:missing_paragraph_body, _}}, problem_language_insert_attrs(resource, %{}, 9))
      true

      iex> resource = %Resource{id: 1, type: "video", subtype: nil}
      iex> {:ok, attrs} = problem_language_insert_attrs(resource, %{"meta_data" => nil}, 9)
      iex> attrs["res_id"]
      1
      iex> attrs["lang_id"]
      9

  """
  def problem_language_insert_attrs(%Resource{type: "problem"} = resource, params, lang_id) do
    if comprehension_problem?(resource, params) do
      build_comprehension_insert_attrs(resource, params, lang_id)
    else
      {:ok, build_default_problem_lang_attrs(resource, params, lang_id)}
    end
  end

  def problem_language_insert_attrs(%Resource{} = resource, params, lang_id),
    do: {:ok, build_default_problem_lang_attrs(resource, params, lang_id)}

  @doc false
  defp build_comprehension_insert_attrs(resource, params, lang_id) do
    case paragraph_body_for_comprehension(params) do
      body when is_binary(body) ->
        case create_paragraph(%{"body" => body}) do
          {:ok, %Paragraph{id: pid}} ->
            {:ok,
             %{
               "res_id" => resource.id,
               "lang_id" => lang_id,
               "meta_data" => Map.get(params, "meta_data"),
               "paragraph_id" => pid
             }}

          {:error, cs} ->
            {:error, cs}
        end

      _ ->
        {:error, {:missing_paragraph_body, "`paragraph` is required for comprehension problems"}}
    end
  end

  @doc false
  defp build_default_problem_lang_attrs(resource, params, lang_id) do
    %{
      "res_id" => resource.id,
      "lang_id" => lang_id,
      "meta_data" => Map.get(params, "meta_data"),
      "paragraph_id" => Map.get(params, "paragraph_id")
    }
  end

  @doc """
  Builds attrs for updating a `problem_lang` row from a resource PATCH (same `lang_code` row).

  For comprehension problems, when `paragraph` is present in params it upserts the linked paragraph
  body and refreshes `paragraph_id`. The transient `paragraph` key is always stripped before passing
  to the changeset.

  ## Examples

      iex> resource = %Resource{type: "problem", subtype: "mcq_single_answer"}
      iex> pl = %ProblemLanguage{id: 1, res_id: 1, lang_id: 1, paragraph_id: nil, meta_data: %{}}
      iex> attrs = problem_language_update_attrs(resource, %{"paragraph" => "ignored"}, pl)
      iex> Map.has_key?(attrs, "paragraph")
      false

  """
  def problem_language_update_attrs(
        %Resource{type: "problem"} = resource,
        params,
        %ProblemLanguage{} = pl
      ) do
    params =
      if comprehension_problem?(resource, params) do
        sync_paragraph_on_update(params, pl)
      else
        params
      end

    Map.drop(params, ["paragraph"])
  end

  def problem_language_update_attrs(_resource, params, _pl),
    do: Map.drop(params, ["paragraph"])

  @doc false
  defp sync_paragraph_on_update(params, %ProblemLanguage{} = pl) do
    case paragraph_body_for_comprehension(params) do
      body when is_binary(body) ->
        case upsert_paragraph_for_problem_lang(pl.paragraph_id, body) do
          {:ok, %Paragraph{id: pid}} -> Map.put(params, "paragraph_id", pid)
          {:error, _} -> params
        end

      _ ->
        params
    end
  end

  @doc false
  defp upsert_paragraph_for_problem_lang(nil, body),
    do: create_paragraph(%{"body" => body})

  @doc false
  defp upsert_paragraph_for_problem_lang(paragraph_id, body) when is_integer(paragraph_id) do
    case Repo.get(Paragraph, paragraph_id) do
      %Paragraph{} = p -> update_paragraph(p, %{"body" => body})
      nil -> create_paragraph(%{"body" => body})
    end
  end

  @doc false
  defp comprehension_label?(s) when is_binary(s),
    do: s |> String.trim() |> String.downcase() == "comprehension"

  @doc false
  defp comprehension_label?(_), do: false

  @doc false
  defp nonempty_trimmed(s) when is_binary(s) do
    t = String.trim(s)
    if t == "", do: nil, else: t
  end

  @doc false
  defp nonempty_trimmed(_), do: nil
end
