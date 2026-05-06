defmodule Dbservice.Paragraphs do
  @moduledoc """
  The Paragraphs context.

  Paragraph text for reading-comprehension problems; linked from `problem_lang.paragraph_id`
  and echoed in `problem_lang.meta_data["paragraph_id"]` for API consumers.
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
  Returns true when the resource is a problem marked as comprehension:
  merged `type_params["resource_type"]`, request `subtype`, or the resource `subtype`,
  compares equal to `"comprehension"` (case-insensitive).

  ## Examples

      iex> resource = %Resource{type: "problem", subtype: nil, type_params: %{"resource_type" => "comprehension"}}
      iex> comprehension_problem?(resource, %{})
      true

      iex> resource = %Resource{type: "problem", subtype: "comprehension", type_params: %{}}
      iex> comprehension_problem?(resource, %{})
      true

      iex> resource = %Resource{type: "problem", subtype: "mcq", type_params: %{}}
      iex> comprehension_problem?(resource, %{})
      false

  """
  def comprehension_problem?(%Resource{type: "problem"} = resource, params) when is_map(params) do
    tp = merged_type_params(resource, params)

    comprehension_label?(tp["resource_type"]) or
      comprehension_label?(params["subtype"] || resource.subtype)
  end

  def comprehension_problem?(_, _), do: false

  @doc false
  defp merged_type_params(%Resource{type_params: stored}, params)
       when is_map(stored) and is_map(params) do
    Map.merge(stored, params["type_params"] || %{})
  end

  @doc false
  defp merged_type_params(%Resource{type_params: stored}, _)
       when is_map(stored),
       do: stored

  @doc false
  defp merged_type_params(_, params), do: params["type_params"] || %{}

  @doc false
  defp comprehension_label?(s) when is_binary(s) do
    s |> String.trim() |> String.downcase() == "comprehension"
  end

  @doc false
  defp comprehension_label?(_), do: false

  @doc """
  Resolves reading-passage body for comprehension workflows from mixed request shapes.

  Checks, in order: `paragraph_body`, `paragraph`, then `meta_data["passage"]`,
  `meta_data["paragraph_body"]`, `meta_data["reading_passage"]`. Non-map params return `nil`.

  ## Examples

      iex> paragraph_body_for_comprehension(%{"paragraph_body" => " Hello "})
      "Hello"

      iex> paragraph_body_for_comprehension(%{"meta_data" => %{"passage" => "Text"}})
      "Text"

      iex> paragraph_body_for_comprehension(:invalid)
      nil

  """
  def paragraph_body_for_comprehension(params) when is_map(params) do
    case nonempty_trimmed(params["paragraph_body"]) do
      nil ->
        case nonempty_trimmed(params["paragraph"]) do
          nil ->
            case params["meta_data"] do
              meta when is_map(meta) ->
                nonempty_trimmed(meta["passage"]) ||
                  nonempty_trimmed(meta["paragraph_body"]) ||
                  nonempty_trimmed(meta["reading_passage"])

              _ ->
                nil
            end

          body ->
            body
        end

      body ->
        body
    end
  end

  def paragraph_body_for_comprehension(_), do: nil

  @doc """
  Builds attrs for inserting a `problem_lang` row when creating a resource.

  For comprehension problems (`comprehension_problem?/2`), creates a paragraph, sets `paragraph_id`,
  and merges `meta_data["paragraph_id"]`.

  Otherwise returns inserted attrs from params only.

  ## Examples

      iex> resource = %Resource{id: 1, type: "problem", subtype: "mcq", type_params: %{"resource_type" => "comprehension"}}
      iex> match?({:error, {:missing_paragraph_body, _}}, problem_language_insert_attrs(resource, %{}, 9))
      true

      iex> resource = %Resource{id: 1, type: "video", subtype: nil, type_params: %{}}
      iex> {:ok, attrs} = problem_language_insert_attrs(resource, %{"meta_data" => nil}, 9)
      iex> attrs["res_id"]
      1
      iex> attrs["lang_id"]
      9

  """
  def problem_language_insert_attrs(%Resource{type: "problem"} = resource, params, lang_id) do
    if comprehension_problem?(resource, params) do
      case paragraph_body_for_comprehension(params) do
        body when is_binary(body) ->
          case create_paragraph(%{"body" => body}) do
            {:ok, %Paragraph{id: pid}} ->
              meta = merge_meta(Map.get(params, "meta_data"), %{"paragraph_id" => pid})

              {:ok,
               %{
                 "res_id" => resource.id,
                 "lang_id" => lang_id,
                 "meta_data" => meta,
                 "paragraph_id" => pid
               }}

            {:error, cs} ->
              {:error, cs}
          end

        _ ->
          {:error,
           {:missing_paragraph_body,
            "paragraph_body (or passage in meta_data) is required for comprehension problems"}}
      end
    else
      {:ok,
       %{
         "res_id" => resource.id,
         "lang_id" => lang_id,
         "meta_data" => Map.get(params, "meta_data"),
         "paragraph_id" => Map.get(params, "paragraph_id")
       }}
    end
  end

  def problem_language_insert_attrs(%Resource{} = resource, params, lang_id) do
    {:ok,
     %{
       "res_id" => resource.id,
       "lang_id" => lang_id,
       "meta_data" => Map.get(params, "meta_data"),
       "paragraph_id" => Map.get(params, "paragraph_id")
     }}
  end

  @doc """
  Builds attrs for updating a `problem_lang` row from a resource PATCH (same `lang_code` row).

  For comprehension problems, updates or creates linked paragraph body when passage fields are present,
  and keeps `meta_data["paragraph_id"]` in sync. Strips internal-only keys (`paragraph_body`, `paragraph`).

  ## Examples

      iex> resource = %Resource{type: "problem", subtype: "mcq", type_params: %{}}
      iex> pl = %ProblemLanguage{id: 1, res_id: 1, lang_id: 1, paragraph_id: nil, meta_data: %{}}
      iex> attrs = problem_language_update_attrs(resource, %{"lang_code" => "en"}, pl)
      iex> Map.has_key?(attrs, "paragraph_body")
      false

  """
  def problem_language_update_attrs(
        %Resource{type: "problem"} = resource,
        params,
        %ProblemLanguage{} = pl
      ) do
    params =
      if comprehension_problem?(resource, params) do
        attrs_for_comprehension_update(params, pl)
      else
        params
      end

    Map.drop(params, ["paragraph_body", "paragraph"])
  end

  def problem_language_update_attrs(_resource, params, _pl),
    do: Map.drop(params, ["paragraph_body", "paragraph"])

  @doc false
  defp attrs_for_comprehension_update(params, pl) do
    case paragraph_body_for_comprehension(params) do
      body when is_binary(body) ->
        case upsert_paragraph_for_problem_lang(pl.paragraph_id, body) do
          {:ok, %Paragraph{id: pid}} ->
            meta =
              merge_meta(Map.get(params, "meta_data") || pl.meta_data, %{"paragraph_id" => pid})

            Map.merge(params, %{"meta_data" => meta, "paragraph_id" => pid})

          {:error, _} ->
            params
        end

      _ ->
        meta_base = Map.get(params, "meta_data")

        merged =
          cond do
            is_map(meta_base) && is_integer(pl.paragraph_id) ->
              merge_meta(meta_base, %{"paragraph_id" => pl.paragraph_id})

            is_map(meta_base) ->
              meta_base

            is_integer(pl.paragraph_id) ->
              merge_meta(pl.meta_data || %{}, %{"paragraph_id" => pl.paragraph_id})

            true ->
              meta_base || pl.meta_data
          end

        out =
          if is_nil(merged) do
            params
          else
            Map.merge(params, %{"meta_data" => merged})
          end

        if is_integer(pl.paragraph_id) do
          Map.put(out, "paragraph_id", pl.paragraph_id)
        else
          out
        end
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
  defp merge_meta(nil, extra), do: extra

  @doc false
  defp merge_meta(%{} = m, extra), do: Map.merge(m, extra)

  @doc false
  defp merge_meta(other, extra) when is_map(other),
    do: Map.merge(normalize_string_map(other), extra)

  @doc false
  defp merge_meta(_, extra), do: extra

  @doc false
  defp normalize_string_map(m) when is_map(m),
    do: for({k, v} <- m, into: %{}, do: {to_string(k), v})

  @doc false
  defp nonempty_trimmed(nil), do: nil

  @doc false
  defp nonempty_trimmed(s) when is_binary(s) do
    t = String.trim(s)
    if t == "", do: nil, else: t
  end

  @doc false
  defp nonempty_trimmed(_), do: nil
end
