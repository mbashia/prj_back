defmodule BettingSystemWeb.UserLive.Index do
  use BettingSystemWeb, :live_view
  alias BettingSystem.Users
  alias BettingSystem.Games
  alias BettingSystem.Bet
  alias BettingSystem.Accounts.User
  alias BettingSystem.Accounts
  alias BettingSystem.Repo
  alias BettingSystem.Games
  alias BettingSystem.Betslips



  @impl true
  def mount(_params, session, socket) do
   :timer.send_interval(20000, self(), :update_games)

    user = Accounts.get_user_by_session_token(session["user_token"]) |> Repo.preload(:betslips)
    users = Users.list_users()
    user_bets = Bet.get_all_bets(user.id)

    Enum.each(user_bets, fn bet ->
      bet_items = bet.bet_items
      game_ids = Map.values(bet_items)

      Enum.each(game_ids, fn game_id ->
        game = Games.get_game!(game_id)

        IO.inspect(game)
      end)
    end)

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:current_user, user)
     |> assign(:check_bet_history, 0)
     |> assign(:bets, user_bets)
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit user")
    |> assign(:user, Users.get_user!(id))
  end

  # defp apply_action(socket, :new, _params) do
  #   socket
  #   |> assign(:page_title, "New user")
  #   |> assign(:user, %User{})
  # end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing users")
    |> assign(:sport, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Users.get_user!(id)
    cond do
      user.status == "active" ->
        case Users.update_user(user, %{status: "inactive"}) do
          {:ok, _user} ->
           {:noreply,
           socket
            |> put_flash(:info, "User deactivated successfully")
          }
          {:error, _changeset} ->
            {:noreply,
            socket
            |> put_flash(:error, "Failed to deactivate user")}
        end

      user.status == "inactive" ->
        case Users.update_user(user, %{status: "active"}) do
          {:ok, _user} ->
            {:noreply,
            socket
            |> put_flash(:info, "User activated successfully")
          }
          {:error, _changeset} ->
            {:noreply,
            socket
            |> put_flash(:error, "Failed to activate user:")}
        end

      true ->
        socket
        |> put_flash(:error, "Invalid user status")
    end
    # {:ok, _} = Users.delete_user(users)

    # {:noreply, assign(socket, :users, Users.list_users())}
  end

  def handle_event("bet history", params, socket) do
    {:noreply,
     socket
     |> assign(:check_bet_history, 1)}
  end
  def handle_info(:update_games, socket) do
    pending_games = Games.list_pending_games()
    IO.inspect(pending_games)
    Enum.each(pending_games, fn game ->
      random_result = Enum.random(["team1 win", "game_draw", "team2 win"])


      random_updates = %{"status"=>"completed", "result"=> "team1 win"}
      Games.update_game(game,random_updates)

    end)

    user_betslips = Betslips.get_betslip_user_id(socket.assigns.current_user.id)
      IO.inspect(user_betslips)
      Enum.each(user_betslips, fn betslip ->
        game_id = betslip.game_id
        game = Games.get_game!(game_id)
        IO.write("im here")
        case game.status do
          "completed" ->
          if game.result == betslip.result_type do
            Betslips.update_betslip(betslip, %{"end_result"=>"won"})
            IO.write("if true")
          else
            Betslips.update_betslip(betslip, %{"end_result"=>"lost"})
            IO.write("if false")

          end
          "pending" ->
            pending = "pending"
# this code from here  i cant rembember i was in the zone and it might not be working check later
          user_bets = Bet.get_all_bets(socket.assigns.current_user.id)
          Enum.each(user_bets, fn bet ->
            game_ids = Map.values(bet.bet_items)

            Enum.each(game_ids, fn game_id ->
              IO.write("im here")
              betslip = Betslips.check_betslip!(socket.assigns.current_user.id,game_id)
              case betslip.game.status do
                "completed"->
                case  betslip.end_result do
                  "lost"->
                  Bet.update_bets(bet, %{"end_result"=>"lost"})
                  "won" ->
                    Bet.update_bets(bet, %{"end_result"=>"won"})


                end
                 _ ->

                        _nothing= "nothing"
              end

            end)
            end)


        end


        # case {game.result, betslip.result} do
        #   {game_result, betslip_result} when game_result == betslip_result ->
        #     IO.puts "Bet slip #{betslip.id} matches the game result."
        #     # Perform actions for a successful match (x)

        #   _ ->
        #     IO.puts "Bet slip #{betslip.id} does not match the game result."
        #     # Perform actions for a mismatch (y)
        # end
      end)

    {:noreply, socket}
  end
end
