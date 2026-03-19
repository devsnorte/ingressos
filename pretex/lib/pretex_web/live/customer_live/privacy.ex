defmodule PretexWeb.CustomerLive.Privacy do
  use PretexWeb, :live_view

  alias Pretex.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-12 space-y-12">
        <div class="text-center">
          <.header>
            Privacy & Data
            <:subtitle>Manage your personal data in compliance with LGPD</:subtitle>
          </.header>
        </div>

        <%!-- Data Export Section --%>
        <div
          id="data-export-hook"
          phx-hook=".DataExport"
          class="card border border-base-300 bg-base-100 rounded-2xl p-8 space-y-4 shadow-sm"
        >
          <div class="flex items-start gap-4">
            <div class="rounded-full bg-info/10 p-3 shrink-0">
              <.icon name="hero-arrow-down-tray" class="size-6 text-info" />
            </div>
            <div class="space-y-1">
              <h2 class="text-lg font-semibold text-base-content">Export my data</h2>
              <p class="text-sm text-base-content/60">
                Download a copy of your personal data that Pretex holds. The file will be downloaded as JSON.
              </p>
            </div>
          </div>
          <div class="pt-2">
            <button
              id="export-data-btn"
              phx-click="export_data"
              class="inline-flex items-center gap-2 rounded-lg bg-info px-5 py-2.5 text-sm font-semibold text-info-content shadow-sm hover:brightness-110 transition-all duration-150"
            >
              <.icon name="hero-arrow-down-tray" class="size-4" /> Export my data
            </button>
          </div>
        </div>

        <%!-- Account Deletion Section --%>
        <div class="card border border-error/30 bg-base-100 rounded-2xl p-8 space-y-4 shadow-sm">
          <div class="flex items-start gap-4">
            <div class="rounded-full bg-error/10 p-3 shrink-0">
              <.icon name="hero-trash" class="size-6 text-error" />
            </div>
            <div class="space-y-1">
              <h2 class="text-lg font-semibold text-error">Delete my account</h2>
              <p class="text-sm text-base-content/60">
                Permanently delete your account and all associated data. This action cannot be undone.
              </p>
            </div>
          </div>

          <div class="alert alert-warning rounded-xl">
            <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
            <p class="text-sm">
              To confirm deletion, type your email address
              <strong>{@current_scope.customer.email}</strong>
              below.
            </p>
          </div>

          <.form
            for={@delete_form}
            id="delete-account-form"
            phx-submit="delete_account"
            class="space-y-4"
          >
            <.input
              field={@delete_form[:email_confirmation]}
              type="email"
              label="Confirm your email address"
              placeholder={@current_scope.customer.email}
              autocomplete="off"
              required
            />
            <button
              id="delete-account-btn"
              type="submit"
              class="inline-flex items-center gap-2 rounded-lg bg-error px-5 py-2.5 text-sm font-semibold text-error-content shadow-sm hover:brightness-110 transition-all duration-150"
            >
              <.icon name="hero-trash" class="size-4" /> Permanently delete my account
            </button>
          </.form>
        </div>
      </div>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".DataExport">
      export default {
        mounted() {
          this.handleEvent("download_data", ({filename, content}) => {
            const blob = new Blob([content], {type: "application/json"});
            const url = URL.createObjectURL(blob);
            const a = document.createElement("a");
            a.href = url;
            a.download = filename;
            a.click();
            URL.revokeObjectURL(url);
          });
        }
      }
    </script>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    delete_form = to_form(%{"email_confirmation" => ""}, as: :delete)

    {:ok,
     socket
     |> assign(:page_title, "Privacy & Data")
     |> assign(:delete_form, delete_form)}
  end

  @impl true
  def handle_event("export_data", _params, socket) do
    customer = socket.assigns.current_scope.customer

    data = %{
      email: customer.email,
      name: Map.get(customer, :name),
      exported_at: DateTime.utc_now()
    }

    socket =
      push_event(socket, "download_data", %{
        filename: "pretex-data-export.json",
        content: Jason.encode!(data)
      })

    {:noreply, socket}
  end

  def handle_event(
        "delete_account",
        %{"delete" => %{"email_confirmation" => typed_email}},
        socket
      ) do
    customer = socket.assigns.current_scope.customer

    if String.downcase(typed_email) == String.downcase(customer.email) do
      case Customers.delete_customer(customer) do
        {:ok, _customer} ->
          {:noreply, redirect(socket, to: ~p"/customers/log-out")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Something went wrong. Please try again.")}
      end
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "The email address you entered does not match your account email."
       )}
    end
  end
end
