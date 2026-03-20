defmodule PretexWeb.Admin.GiftCardLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Organizations
  alias Pretex.GiftCards
  alias Pretex.GiftCards.GiftCard

  @impl true
  def mount(%{"org_id" => org_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    gift_cards = GiftCards.list_gift_cards(org)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:page_title, "Vale-Presentes — #{org.name}")
      |> assign(:gift_card, nil)
      |> assign(:form, nil)
      |> assign(:top_up_form, nil)
      |> stream(:gift_cards, gift_cards)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Vale-Presentes — #{socket.assigns.org.name}")
    |> assign(:gift_card, nil)
    |> assign(:form, nil)
    |> assign(:top_up_form, nil)
  end

  defp apply_action(socket, :new, _params) do
    gift_card = %GiftCard{}
    generated_code = GiftCards.generate_code()

    socket
    |> assign(:page_title, "Novo Vale-Presente")
    |> assign(:gift_card, gift_card)
    |> assign(
      :form,
      to_form(GiftCards.change_gift_card(gift_card, %{code: generated_code}))
    )
    |> assign(:top_up_form, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    gift_card = GiftCards.get_gift_card!(id)

    socket
    |> assign(:page_title, "Editar Vale-Presente")
    |> assign(:gift_card, gift_card)
    |> assign(:form, to_form(GiftCards.change_gift_card(gift_card)))
    |> assign(:top_up_form, nil)
  end

  defp apply_action(socket, :top_up, %{"id" => id}) do
    gift_card = GiftCards.get_gift_card!(id)

    socket
    |> assign(:page_title, "Recarregar Vale-Presente")
    |> assign(:gift_card, gift_card)
    |> assign(:form, nil)
    |> assign(:top_up_form, to_form(%{"amount_cents" => ""}, as: :top_up))
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"gift_card" => params}, socket) do
    changeset =
      socket.assigns.gift_card
      |> GiftCards.change_gift_card(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"gift_card" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    gift_card = GiftCards.get_gift_card!(id)

    case GiftCards.delete_gift_card(gift_card) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Vale-presente removido com sucesso.")
         |> stream_delete(:gift_cards, gift_card)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover o vale-presente.")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    gift_card = GiftCards.get_gift_card!(id)
    new_active = !gift_card.active

    case GiftCards.update_gift_card(gift_card, %{active: new_active}) do
      {:ok, updated} ->
        {:noreply, stream_insert(socket, :gift_cards, updated)}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Não foi possível alterar o status do vale-presente.")}
    end
  end

  def handle_event("save_top_up", %{"top_up" => %{"amount_cents" => amt_str}}, socket) do
    org = socket.assigns.org
    gift_card = socket.assigns.gift_card

    case parse_integer(amt_str) do
      amount when is_integer(amount) and amount > 0 ->
        case GiftCards.top_up(gift_card, amount) do
          {:ok, updated_gc} ->
            {:noreply,
             socket
             |> put_flash(:info, "Vale-presente recarregado com sucesso.")
             |> stream_insert(:gift_cards, updated_gc)
             |> push_patch(to: ~p"/admin/organizations/#{org}/gift-cards")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Não foi possível recarregar o vale-presente.")}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Por favor informe um valor válido maior que zero.")
         |> assign(:top_up_form, to_form(%{"amount_cents" => amt_str}, as: :top_up))}
    end
  end

  def handle_event("generate_code", _, socket) do
    new_code = GiftCards.generate_code()
    gift_card = socket.assigns.gift_card

    changeset = GiftCards.change_gift_card(gift_card, %{code: new_code})

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("close_modal", _params, socket) do
    org = socket.assigns.org
    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/gift-cards")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_create(socket, params) do
    org = socket.assigns.org

    case GiftCards.create_gift_card(org, params) do
      {:ok, gift_card} ->
        {:noreply,
         socket
         |> put_flash(:info, "Vale-presente criado com sucesso.")
         |> stream_insert(:gift_cards, gift_card)
         |> push_patch(to: ~p"/admin/organizations/#{org}/gift-cards")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    org = socket.assigns.org
    gift_card = socket.assigns.gift_card

    case GiftCards.update_gift_card(gift_card, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Vale-presente atualizado com sucesso.")
         |> stream_insert(:gift_cards, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/gift-cards")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp parse_integer(v) when is_binary(v) do
    trimmed = String.trim(v)

    case Integer.parse(trimmed) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_integer(v) when is_integer(v), do: v
  defp parse_integer(_), do: nil

  defp format_balance(cents) when is_integer(cents) do
    reais = div(cents, 100)
    centavos = rem(cents, 100)
    "R$ #{reais},#{String.pad_leading(Integer.to_string(centavos), 2, "0")}"
  end

  defp format_balance(_), do: "R$ 0,00"

  defp format_expiry(nil), do: "Nunca expira"

  defp format_expiry(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  end
end
