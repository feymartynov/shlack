defmodule Shlack.RoomChannel do
  use Phoenix.Channel
  require Logger

  alias Shlack.Repo
  alias Shlack.Channel
  alias Shlack.User
  alias Shlack.Message

  def join("rooms:" <> _, _, socket) do
    send(self, :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    user = socket.assigns.user

    channels = Repo.all(Channel) |> Enum.map &(%{name: &1.name})
    push socket, "channels", %{channels: channels}

    users = Repo.all(User) |> Enum.map &(%{name: &1.name, online: &1.online})
    push socket, "users", %{users: users}

    broadcast! socket, "user_online", %{user: %{name: user.name, online: user.online}}
    {:noreply, socket}
  end

  def terminate(_, socket) do
    user = %{socket.assigns.user | online: false}
    Repo.update!(user)
    broadcast! socket, "user_offline", %{user: %{name: user.name, online: user.online}}
    {:ok, socket}
  end

  def handle_in("ping", _, socket) do
    {:reply, :pong, socket}
  end

  def handle_in("send_message", %{"text" => text, "channel" => channel_name}, socket) do
    user = socket.assigns.user
    channel = Repo.get_by(Channel, name: channel_name)

    message = Repo.insert(%Message{channel: channel, user: user, text: text})

    if message do
      broadcast! socket, "incoming_message", %{
        channel: channel.name,
        user: user.name,
        text: text}

      {:reply, :ok, socket}
    else
      {:reply, {:error, %{reason: "message save failed"}}, socket}
    end
  end

  defp find_or_create_channel(name, socket) do
    Repo.get_by(Channel, name: name) || create_channel(name, socket)
  end

  defp create_channel(name, socket) do
    channel = Repo.insert(%Channel{name: name})

    if channel do
      broadcast! socket, "channel_created", %{name: name}
    end

    channel
  end
end
