defmodule Dbservice.LmsStudentRegistrationMode do
  @moduledoc false

  @type mode :: String.t()

  @phone "phone"
  @contract_version "1"
  @production_active_mode @phone

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec production_active_mode() :: mode()
  def production_active_mode, do: production_mode()

  @spec active_mode() :: mode()
  if Mix.env() == :test do
    @test_override_key {__MODULE__, :active_mode_override}

    def active_mode do
      Process.get(@test_override_key, production_mode())
    end

    @doc false
    @spec put_test_active_mode(mode() | nil) :: :ok
    def put_test_active_mode(mode) when mode in [@phone, "approved"] do
      Process.put(@test_override_key, mode)
      :ok
    end

    def put_test_active_mode(nil) do
      Process.delete(@test_override_key)
      :ok
    end
  else
    def active_mode, do: production_mode()
  end

  @spec validate(map()) :: :ok | {:error, map()}
  def validate(params) when is_map(params) do
    if params["registration_mode"] == active_mode() and
         params["registration_mode_version"] == contract_version() do
      :ok
    else
      mismatch()
    end
  end

  def validate(_params), do: mismatch()

  defp production_mode, do: :erlang.iolist_to_binary(@production_active_mode)

  defp mismatch do
    {:error,
     %{
       "code" => "registration_mode_mismatch",
       "message" => "Registration mode does not match the active LMS contract",
       "status" => 409
     }}
  end
end
