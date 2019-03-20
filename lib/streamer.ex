defmodule Streamer do
  use GenServer
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], debug: [:trace])
  end

  def init(_args) do
    {:ok, %{}, {:continue, :connect}}
  end

  def handle_continue(:connect, state) do
    {:ok, conn} = Mint.HTTP.connect(:http, "localhost", 8001)
    {:noreply, Map.put(state, :conn, conn), {:continue, :request}}
  end

  def handle_continue(:request, %{conn: conn} = state) do
    {:ok, conn, request_ref} =
      Mint.HTTP.request(
        conn,
        "GET",
        "/api/v1/watch/namespaces?resourceVersion=0&timeoutSeconds=90",
        []
      )

    {:noreply, Map.put(state, :request, request_ref)}
  end

  def handle_info({:tcp, _port, body} = message, %{conn: conn, request: request} = state) do
    case Mint.HTTP.stream(conn, message) do
      {:ok, _conn, _responses} ->
        {:stop, :normal, state}

      {:error, _conn, err, _responses} ->
        Logger.error(fn -> inspect(err) end)
        {:stop, :error, state}
    end
  end
end
