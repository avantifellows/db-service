defmodule Dbservice.Constants.IndianStates do
  @moduledoc """
  The 36 Indian states and union territories, paired with the two-digit UDISE
  state codes that every 11-digit UDISE school code begins with.

  Used to validate a Student's Grade 10 school location: the state must be one
  of the 36, and the UDISE code's first two digits must belong to that state.

  Most states map to exactly one prefix. A few carry legacy prefixes as well,
  because UDISE codes issued before a state reorganisation are still printed on
  marksheets and still present in `school.udise_code`:

    * Dadra & Nagar Haveli and Daman & Diu merged in 2020. Schools in this UT
      hold codes starting 25 or 26 (the two pre-merger UTs) even though the
      UT's own state code is 38 - all three appear in our own school table.
    * Ladakh separated from Jammu & Kashmir in 2019; older codes start with 01.
    * Telangana separated from Andhra Pradesh in 2014; older codes start with 28.
  """

  # {canonical name, [accepted UDISE prefixes], [extra spellings we accept]}
  # Kept alphabetical so `all/0` can feed a dropdown directly.
  @states [
    {"Andaman & Nicobar Islands", ["35"], []},
    {"Andhra Pradesh", ["28"], []},
    {"Arunachal Pradesh", ["12"], []},
    {"Assam", ["18"], []},
    {"Bihar", ["10"], []},
    {"Chandigarh", ["04"], []},
    {"Chhattisgarh", ["22"], ["Chattisgarh"]},
    {"Dadra & Nagar Haveli & Daman & Diu", ["38", "25", "26"],
     ["Dadra & Nagar Haveli", "Daman & Diu", "DNHDD"]},
    {"Delhi", ["07"], ["NCT of Delhi", "New Delhi"]},
    {"Goa", ["30"], []},
    {"Gujarat", ["24"], []},
    {"Haryana", ["06"], []},
    {"Himachal Pradesh", ["02"], []},
    {"Jammu & Kashmir", ["01"], []},
    {"Jharkhand", ["20"], []},
    {"Karnataka", ["29"], []},
    {"Kerala", ["32"], []},
    {"Ladakh", ["37", "01"], []},
    {"Lakshadweep", ["31"], []},
    {"Madhya Pradesh", ["23"], []},
    {"Maharashtra", ["27"], []},
    {"Manipur", ["14"], []},
    {"Meghalaya", ["17"], []},
    {"Mizoram", ["15"], []},
    {"Nagaland", ["13"], []},
    {"Odisha", ["21"], ["Orissa"]},
    {"Puducherry", ["34"], ["Pondicherry"]},
    {"Punjab", ["03"], []},
    {"Rajasthan", ["08"], []},
    {"Sikkim", ["11"], []},
    {"Tamil Nadu", ["33"], []},
    {"Telangana", ["36", "28"], []},
    {"Tripura", ["16"], []},
    {"Uttar Pradesh", ["09"], []},
    {"Uttarakhand", ["05"], ["Uttaranchal"]},
    {"West Bengal", ["19"], []}
  ]

  @names Enum.map(@states, fn {name, _prefixes, _spellings} -> name end)

  @prefixes_by_name Map.new(@states, fn {name, prefixes, _spellings} -> {name, prefixes} end)

  # Normalization is spelled out here as data rather than as a function call so
  # the lookup map can be built at compile time; `normalize/1` below applies the
  # same steps to incoming values.
  @lookup Map.new(
            Enum.flat_map(@states, fn {name, _prefixes, spellings} ->
              Enum.map([name | spellings], fn spelling ->
                key =
                  spelling
                  |> String.downcase()
                  |> String.replace("&", " and ")
                  |> String.replace(~r/\(ut\)/, " ")
                  |> String.replace(~r/[^a-z]+/, " ")
                  |> String.trim()

                {key, name}
              end)
            end)
          )

  @doc """
  All 36 states and union territories, alphabetically. Suitable for a dropdown.
  """
  def all, do: @names

  @doc """
  Resolves a user-supplied spelling to its canonical name.

  Tolerates case, surrounding whitespace, repeated spaces, "and" written out,
  and a trailing "(UT)" - all of which appear in our existing school rows and in
  teacher-entered data. Returns `:error` for anything unrecognized.
  """
  def canonical_name(value) when is_binary(value) do
    Map.fetch(@lookup, normalize(value))
  end

  def canonical_name(_value), do: :error

  @doc """
  The UDISE prefixes accepted for a state, by canonical name.
  """
  def udise_prefixes(canonical_name), do: Map.get(@prefixes_by_name, canonical_name, [])

  @doc """
  Whether an 11-digit UDISE code's first two digits belong to the given state.
  """
  def udise_code_matches_state?(udise_code, canonical_name)
      when is_binary(udise_code) and is_binary(canonical_name) do
    String.slice(udise_code, 0, 2) in udise_prefixes(canonical_name)
  end

  def udise_code_matches_state?(_udise_code, _canonical_name), do: false

  defp normalize(value) do
    value
    |> String.downcase()
    |> String.replace("&", " and ")
    |> String.replace(~r/\(ut\)/, " ")
    |> String.replace(~r/[^a-z]+/, " ")
    |> String.trim()
  end
end
