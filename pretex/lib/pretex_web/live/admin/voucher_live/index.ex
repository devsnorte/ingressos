defmodule PretexWeb.Admin.VoucherLive.Index do
  use PretexWeb, :live_view

  alias Pretex.Events
  alias Pretex.Organizations
  alias Pretex.Vouchers
  alias Pretex.Vouchers.Voucher

  @impl true
  def mount(%{"org_id" => org_id, "event_id" => event_id}, _session, socket) do
    org = Organizations.get_organization!(org_id)
    event = Events.get_event!(event_id)
    vouchers = Vouchers.list_vouchers(event)
    tags = Vouchers.list_tags(event)

    socket =
      socket
      |> assign(:org, org)
      |> assign(:event, event)
      |> assign(:page_title, "Vouchers — #{event.name}")
      |> assign(:tags, tags)
      |> assign(:tag_filter, nil)
      |> assign(:voucher, nil)
      |> assign(:form, nil)
      |> assign(:bulk_form, nil)
      |> stream(:vouchers, vouchers)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Vouchers — #{socket.assigns.event.name}")
    |> assign(:voucher, nil)
    |> assign(:form, nil)
    |> assign(:bulk_form, nil)
  end

  defp apply_action(socket, :new, _params) do
    voucher = %Voucher{}

    socket
    |> assign(:page_title, "Novo Voucher")
    |> assign(:voucher, voucher)
    |> assign(:form, to_form(Vouchers.change_voucher(voucher)))
    |> assign(:bulk_form, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    voucher = Vouchers.get_voucher!(id)

    socket
    |> assign(:page_title, "Editar Voucher")
    |> assign(:voucher, voucher)
    |> assign(:form, to_form(Vouchers.change_voucher(voucher)))
    |> assign(:bulk_form, nil)
  end

  defp apply_action(socket, :bulk, _params) do
    bulk_attrs = %{
      "prefix" => "",
      "quantity" => "10",
      "effect" => "fixed_discount",
      "value" => "0",
      "tag" => "",
      "valid_until" => "",
      "max_uses" => ""
    }

    socket
    |> assign(:page_title, "Geração em Lote — Vouchers")
    |> assign(:voucher, nil)
    |> assign(:form, nil)
    |> assign(:bulk_form, to_form(bulk_attrs, as: :bulk))
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"voucher" => params}, socket) do
    changeset =
      socket.assigns.voucher
      |> Vouchers.change_voucher(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"voucher" => params}, socket) do
    case socket.assigns.live_action do
      :new -> do_create(socket, params)
      :edit -> do_update(socket, params)
    end
  end

  def handle_event("validate_bulk", %{"bulk" => params}, socket) do
    {:noreply, assign(socket, :bulk_form, to_form(params, as: :bulk))}
  end

  def handle_event("save_bulk", %{"bulk" => params}, socket) do
    event = socket.assigns.event
    org = socket.assigns.org

    quantity_str = Map.get(params, "quantity", "0")
    quantity = String.to_integer(quantity_str)

    if quantity < 1 or quantity > 1000 do
      {:noreply,
       socket
       |> put_flash(:error, "Quantidade deve ser entre 1 e 1000.")
       |> assign(:bulk_form, to_form(params, as: :bulk))}
    else
      opts = %{
        prefix: Map.get(params, "prefix", ""),
        quantity: quantity,
        effect: Map.get(params, "effect", "fixed_discount"),
        value: parse_integer(Map.get(params, "value", "0")),
        max_uses: parse_optional_integer(Map.get(params, "max_uses")),
        valid_until: parse_datetime(Map.get(params, "valid_until")),
        tag: nilify_blank(Map.get(params, "tag"))
      }

      case Vouchers.bulk_generate(event, opts) do
        {:ok, count} ->
          vouchers = Vouchers.list_vouchers(event, maybe_tag_opts(socket.assigns.tag_filter))
          tags = Vouchers.list_tags(event)

          {:noreply,
           socket
           |> put_flash(:info, "#{count} voucher(s) gerado(s) com sucesso.")
           |> assign(:tags, tags)
           |> stream(:vouchers, vouchers, reset: true)
           |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/vouchers")}

        {:error, _reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Erro ao gerar vouchers. Tente novamente.")
           |> assign(:bulk_form, to_form(params, as: :bulk))}
      end
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    voucher = Vouchers.get_voucher!(id)

    case Vouchers.delete_voucher(voucher) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Voucher removido com sucesso.")
         |> stream_delete(:vouchers, voucher)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível remover o voucher.")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    voucher = Vouchers.get_voucher!(id)
    new_active = !voucher.active

    case Vouchers.update_voucher(voucher, %{active: new_active}) do
      {:ok, updated} ->
        {:noreply, stream_insert(socket, :vouchers, updated)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Não foi possível alterar o status do voucher.")}
    end
  end

  def handle_event("filter_tag", %{"tag" => tag}, socket) do
    event = socket.assigns.event
    tag_filter = if tag == "", do: nil, else: tag

    vouchers = Vouchers.list_vouchers(event, maybe_tag_opts(tag_filter))

    {:noreply,
     socket
     |> assign(:tag_filter, tag_filter)
     |> stream(:vouchers, vouchers, reset: true)}
  end

  def handle_event("close_modal", _params, socket) do
    org = socket.assigns.org
    event = socket.assigns.event

    {:noreply, push_patch(socket, to: ~p"/admin/organizations/#{org}/events/#{event}/vouchers")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_create(socket, params) do
    event = socket.assigns.event
    org = socket.assigns.org

    case Vouchers.create_voucher(event, params) do
      {:ok, voucher} ->
        tags = Vouchers.list_tags(event)

        {:noreply,
         socket
         |> put_flash(:info, "Voucher criado com sucesso.")
         |> assign(:tags, tags)
         |> stream_insert(:vouchers, voucher)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/vouchers")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp do_update(socket, params) do
    voucher = socket.assigns.voucher
    event = socket.assigns.event
    org = socket.assigns.org

    case Vouchers.update_voucher(voucher, params) do
      {:ok, updated} ->
        tags = Vouchers.list_tags(event)

        {:noreply,
         socket
         |> put_flash(:info, "Voucher atualizado com sucesso.")
         |> assign(:tags, tags)
         |> stream_insert(:vouchers, updated)
         |> push_patch(to: ~p"/admin/organizations/#{org}/events/#{event}/vouchers")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp maybe_tag_opts(nil), do: []
  defp maybe_tag_opts(tag), do: [tag: tag]

  defp parse_integer(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_integer(v) when is_integer(v), do: v
  defp parse_integer(_), do: 0

  defp parse_optional_integer(v) when is_binary(v) do
    trimmed = String.trim(v)

    if trimmed == "" do
      nil
    else
      case Integer.parse(trimmed) do
        {n, _} -> n
        :error -> nil
      end
    end
  end

  defp parse_optional_integer(nil), do: nil
  defp parse_optional_integer(v) when is_integer(v), do: v

  defp parse_datetime(v) when is_binary(v) do
    trimmed = String.trim(v)

    if trimmed == "" do
      nil
    else
      # HTML datetime-local produces "2026-12-31T23:59"; append Z if missing
      normalized = if String.ends_with?(trimmed, "Z"), do: trimmed, else: trimmed <> ":00Z"

      case DateTime.from_iso8601(normalized) do
        {:ok, dt, _offset} -> dt
        {:error, _} -> nil
      end
    end
  end

  defp parse_datetime(_), do: nil

  defp nilify_blank(v) when is_binary(v) do
    trimmed = String.trim(v)
    if trimmed == "", do: nil, else: trimmed
  end

  defp nilify_blank(_), do: nil
end
