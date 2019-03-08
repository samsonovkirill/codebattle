defmodule Codebattle.Bot.PlaybookPlayTest do
  use Codebattle.IntegrationCase

  import Mock

  alias CodebattleWeb.{GameChannel, UserSocket}
  alias Codebattle.GameProcess.{Server, FsmHelpers}
  alias CodebattleWeb.UserSocket
  alias Codebattle.Bot.PlaybookPlayerRunner

  @timeout Application.get_env(:codebattle, Codebattle.Bot)[:timeout]

  test "Bot playing with user", %{conn: conn} do
    task = insert(:task)
    user = insert(:user, %{name: "first", email: "test1@test.test", github_id: 1, rating: 1000})

    conn = put_session(conn, :user_id, user.id)

    playbook_data = %{
      playbook: [
        %{"delta" => [%{"insert" => "t"}], "time" => 20},
        %{"delta" => [%{"retain" => 1}, %{"insert" => "e"}], "time" => 20},
        %{"delta" => [%{"retain" => 2}, %{"insert" => "s"}], "time" => 20},
        %{"lang" => "ruby", "time" => 100}
      ]
    }

    insert(:bot_playbook, %{data: playbook_data, task: task, lang: "ruby"})

    socket = socket(UserSocket, "user_id", %{user_id: user.id, current_user: user})

    with_mocks [
      {Codebattle.CodeCheck.Checker, [], [check: fn _a, _b, _c -> {:ok, "asdf", "asdf"} end]}
    ] do
      # Create game
      {:ok, game_id, task_id} = Codebattle.Bot.GameCreator.call()

      game_topic = "game:#{game_id}"

      # User join to the game
      post(conn, game_path(conn, :join, game_id))

      {:ok, _response, socket} = subscribe_and_join(socket, GameChannel, game_topic)

      # Run bot
      :timer.sleep(300)
      {:ok, pid} = Codebattle.Bot.PlaybookAsyncRunner.start(%{game_id: game_id})

      Codebattle.Bot.PlaybookAsyncRunner.call(%{
        game_id: game_id,
        task_id: task_id
      })

      fsm = Server.fsm(game_id)
      assert fsm.state == :playing

      :timer.sleep(800)
      # bot win the game
      fsm = Server.fsm(game_id)
      IO.inspect(fsm)

      assert fsm.state == :game_over
      assert FsmHelpers.get_first_player(fsm).editor_text == "tes"
      assert FsmHelpers.get_winner(fsm).name == "bot"
    end
  end
end
