defmodule PretexWeb.CustomerLive.Settings do
  use PretexWeb, :live_view

  on_mount({PretexWeb.CustomerAuth, :require_sudo_mode})

  alias Pretex.Customers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address and password settings</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <.form
        for={@password_form}
        id="password_form"
        action={~p"/customers/update-password"}
        method="post"
        phx-change="validate_password"
        phx-submit="update_password"
        phx-trigger-action={@trigger_submit}
      >
        <input
          name={@password_form[:email].name}
          type="hidden"
          id="hidden_customer_email"
          spellcheck="false"
          value={@current_email}
        />
        <.input
          field={@password_form[:password]}
          type="password"
          label="New password"
          autocomplete="new-password"
          spellcheck="false"
          required
        />
        <.input
          field={@password_form[:password_confirmation]}
          type="password"
          label="Confirm new password"
          autocomplete="new-password"
          spellcheck="false"
        />
        <.button variant="primary" phx-disable-with="Saving...">
          Save Password
        </.button>
      </.form>

      <div class="divider" />

      <%!-- TOTP Section --%>
      <div id="totp-section">
        <h2 class="text-lg font-semibold text-gray-900 mb-1">Authenticator App</h2>
        <p class="text-sm text-gray-500 mb-4">
          Use an authenticator app to generate one-time codes for extra security.
        </p>

        <%= if @show_recovery_codes do %>
          <div id="recovery-codes-reveal" class="rounded-2xl bg-amber-50 border border-amber-200 p-6">
            <div class="flex items-center gap-2 mb-3">
              <.icon name="hero-key" class="w-5 h-5 text-amber-600" />
              <h3 class="font-semibold text-amber-900">Save your recovery codes</h3>
            </div>
            <p class="text-sm text-amber-800 mb-4">
              Store these codes somewhere safe. Each code can only be used once.
              If you lose access to your authenticator, you can use these to log in.
            </p>
            <div id="recovery-codes-list" class="grid grid-cols-2 gap-2 mb-4">
              <%= for code <- @recovery_codes do %>
                <code class="font-mono text-sm bg-white border border-amber-200 rounded-lg px-3 py-2 text-center">
                  {code}
                </code>
              <% end %>
            </div>
            <.button
              id="confirm-codes-saved"
              variant="primary"
              phx-click="confirm_codes_saved"
            >
              I have saved these codes
            </.button>
          </div>
        <% else %>
          <%= if @pending_totp_secret do %>
            <div id="totp-setup" class="rounded-2xl border border-gray-100 bg-white shadow-sm p-6">
              <h3 class="font-semibold text-gray-900 mb-3">Scan QR Code</h3>
              <p class="text-sm text-gray-500 mb-4">
                Scan this QR code with your authenticator app (Google Authenticator,
                Authy, etc.), then enter the 6-digit code below to confirm.
              </p>
              <div id="totp-qr" class="flex justify-center mb-4">
                {Phoenix.HTML.raw(@totp_qr_svg)}
              </div>
              <p class="text-xs text-gray-500 mb-1">Or enter this key manually:</p>
              <code
                id="totp-secret-b32"
                class="block font-mono text-sm bg-gray-50 border border-gray-200 rounded-lg px-3 py-2 text-center mb-4 break-all"
              >
                {@totp_secret_b32}
              </code>
              <.form
                for={@totp_verify_form}
                id="totp-verify-form"
                phx-submit="verify_totp_setup"
              >
                <.input
                  field={@totp_verify_form[:code]}
                  type="text"
                  label="Verification Code"
                  placeholder="000000"
                  autocomplete="one-time-code"
                  inputmode="numeric"
                  maxlength="6"
                  required
                />
                <div class="flex gap-2 mt-4">
                  <.button variant="primary" phx-disable-with="Verifying...">
                    Enable Authenticator
                  </.button>
                  <.button id="cancel-totp-setup" phx-click="cancel_totp_setup" type="button">
                    Cancel
                  </.button>
                </div>
              </.form>
            </div>
          <% else %>
            <%= if Customers.Customer.totp_enabled?(@current_scope.customer) do %>
              <div
                id="totp-enabled-badge"
                class="flex items-center justify-between rounded-2xl border border-green-100 bg-green-50 p-4"
              >
                <div class="flex items-center gap-3">
                  <div class="flex h-8 w-8 items-center justify-center rounded-full bg-green-100">
                    <.icon name="hero-check" class="w-4 h-4 text-green-600" />
                  </div>
                  <div>
                    <p class="text-sm font-semibold text-green-900">Authenticator App enabled</p>
                    <p class="text-xs text-green-700">Your account is protected with TOTP.</p>
                  </div>
                </div>
                <.button
                  id="disable-totp-btn"
                  phx-click="disable_totp"
                  data-confirm="Are you sure you want to disable two-factor authentication?"
                >
                  Disable
                </.button>
              </div>
            <% else %>
              <.button
                id="enable-totp-btn"
                variant="primary"
                phx-click="start_totp_setup"
              >
                <.icon name="hero-qr-code" class="w-4 h-4 mr-1" /> Enable Authenticator App
              </.button>
            <% end %>
          <% end %>
        <% end %>
      </div>

      <div class="divider" />

      <%!-- Recovery Codes Section --%>
      <div id="recovery-codes-section">
        <h2 class="text-lg font-semibold text-gray-900 mb-1">Recovery Codes</h2>
        <p class="text-sm text-gray-500 mb-4">
          Recovery codes let you access your account if you lose your authenticator.
          You have <strong>{@remaining_recovery_codes}</strong> unused codes remaining.
        </p>
        <.button
          id="regenerate-codes-btn"
          phx-click="regenerate_recovery_codes"
          data-confirm="This will invalidate all existing recovery codes. Continue?"
        >
          <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> Regenerate Recovery Codes
        </.button>
      </div>

      <div class="divider" />

      <%!-- WebAuthn Section --%>
      <div
        id="webauthn-register-hook"
        phx-hook=".WebAuthnRegister"
        phx-update="ignore"
      >
      </div>

      <div id="webauthn-section">
        <h2 class="text-lg font-semibold text-gray-900 mb-1">Security Keys</h2>
        <p class="text-sm text-gray-500 mb-4">
          Add a hardware security key (e.g. YubiKey) or a passkey for passwordless authentication.
        </p>

        <%= if @webauthn_credentials == [] do %>
          <p id="no-webauthn-keys" class="text-sm text-gray-400 italic mb-4">
            No security keys registered yet.
          </p>
        <% else %>
          <ul id="webauthn-credentials-list" class="space-y-2 mb-4">
            <%= for cred <- @webauthn_credentials do %>
              <li
                id={"webauthn-cred-#{cred.id}"}
                class="flex items-center justify-between rounded-xl border border-gray-100 bg-white px-4 py-3 shadow-sm"
              >
                <div class="flex items-center gap-3">
                  <.icon name="hero-key" class="w-5 h-5 text-gray-400" />
                  <div>
                    <p class="text-sm font-medium text-gray-900">
                      {cred.label || "Security Key"}
                    </p>
                    <%= if cred.last_used_at do %>
                      <p class="text-xs text-gray-400">Last used: {cred.last_used_at}</p>
                    <% else %>
                      <p class="text-xs text-gray-400">Never used</p>
                    <% end %>
                  </div>
                </div>
                <.button
                  id={"delete-webauthn-#{cred.id}"}
                  phx-click="delete_webauthn_credential"
                  phx-value-id={cred.id}
                  data-confirm="Remove this security key?"
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </.button>
              </li>
            <% end %>
          </ul>
        <% end %>

        <%= if @adding_webauthn_key do %>
          <div
            id="webauthn-label-form"
            class="rounded-2xl border border-gray-100 bg-white shadow-sm p-6 mb-4"
          >
            <h3 class="font-semibold text-gray-900 mb-3">Name your security key</h3>
            <.form
              for={@webauthn_label_form}
              id="webauthn-label-form-inner"
              phx-submit="start_webauthn_registration"
            >
              <.input
                field={@webauthn_label_form[:label]}
                type="text"
                label="Key name (e.g. YubiKey 5)"
                placeholder="My Security Key"
                required
              />
              <div class="flex gap-2 mt-4">
                <.button
                  id="confirm-webauthn-label"
                  variant="primary"
                  phx-disable-with="Waiting for key..."
                >
                  Continue
                </.button>
                <.button
                  id="cancel-webauthn-add"
                  phx-click="cancel_webauthn_registration"
                  type="button"
                >
                  Cancel
                </.button>
              </div>
            </.form>
          </div>
        <% else %>
          <.button id="add-webauthn-btn" phx-click="add_webauthn_key">
            <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Add Security Key
          </.button>
        <% end %>
      </div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".WebAuthnRegister">
        export default {
          mounted() {
            this.handleEvent("webauthn_register_options", async (opts) => {
              try {
                const decoded = {
                  ...opts,
                  challenge: this._b64ToBuffer(opts.challenge),
                  user: { ...opts.user, id: this._b64ToBuffer(opts.user.id) }
                };
                const credential = await navigator.credentials.create({ publicKey: decoded });
                const result = {
                  id: credential.id,
                  type: credential.type,
                  response: {
                    attestationObject: this._bufToB64(credential.response.attestationObject),
                    clientDataJSON: this._bufToB64(credential.response.clientDataJSON)
                  }
                };
                this.pushEvent("webauthn_registered", { credential: JSON.stringify(result) });
              } catch(e) {
                this.pushEvent("webauthn_error", { error: e.message });
              }
            });
          },
          _b64ToBuffer(b64) {
            const bin = atob(b64.replace(/-/g, '+').replace(/_/g, '/'));
            return Uint8Array.from(bin, c => c.charCodeAt(0)).buffer;
          },
          _bufToB64(buf) {
            return btoa(String.fromCharCode(...new Uint8Array(buf)))
              .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
          }
        }
      </script>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Customers.update_customer_email(socket.assigns.current_scope.customer, token) do
        {:ok, _customer} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/customers/settings")}
  end

  def mount(_params, _session, socket) do
    customer = socket.assigns.current_scope.customer
    email_changeset = Customers.change_customer_email(customer, %{}, validate_unique: false)
    password_changeset = Customers.change_customer_password(customer, %{}, hash_password: false)
    webauthn_credentials = Customers.list_webauthn_credentials(customer)
    remaining = Customers.remaining_recovery_codes(customer)

    socket =
      socket
      |> assign(:current_email, customer.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:pending_totp_secret, nil)
      |> assign(:totp_qr_svg, nil)
      |> assign(:totp_secret_b32, nil)
      |> assign(:totp_verify_form, to_form(%{"code" => ""}, as: :totp))
      |> assign(:show_recovery_codes, false)
      |> assign(:recovery_codes, [])
      |> assign(:remaining_recovery_codes, remaining)
      |> assign(:webauthn_credentials, webauthn_credentials)
      |> assign(:adding_webauthn_key, false)
      |> assign(:webauthn_label_form, to_form(%{"label" => ""}, as: :webauthn))
      |> assign(:webauthn_registration_challenge, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"customer" => customer_params} = params

    email_form =
      socket.assigns.current_scope.customer
      |> Customers.change_customer_email(customer_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"customer" => customer_params} = params
    customer = socket.assigns.current_scope.customer
    true = Customers.sudo_mode?(customer)

    case Customers.change_customer_email(customer, customer_params) do
      %{valid?: true} = changeset ->
        Customers.deliver_customer_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          customer.email,
          &url(~p"/customers/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"customer" => customer_params} = params

    password_form =
      socket.assigns.current_scope.customer
      |> Customers.change_customer_password(customer_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"customer" => customer_params} = params
    customer = socket.assigns.current_scope.customer
    true = Customers.sudo_mode?(customer)

    case Customers.change_customer_password(customer, customer_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  # ── TOTP ────────────────────────────────────────────────────────────────────

  def handle_event("start_totp_setup", _params, socket) do
    customer = socket.assigns.current_scope.customer
    secret = Customers.generate_totp_secret()
    qr_svg = Customers.totp_qr_svg(customer, secret)
    b32 = Customers.totp_secret_base32(secret)

    socket =
      socket
      |> assign(:pending_totp_secret, secret)
      |> assign(:totp_qr_svg, qr_svg)
      |> assign(:totp_secret_b32, b32)
      |> assign(:totp_verify_form, to_form(%{"code" => ""}, as: :totp))

    {:noreply, socket}
  end

  def handle_event("cancel_totp_setup", _params, socket) do
    socket =
      socket
      |> assign(:pending_totp_secret, nil)
      |> assign(:totp_qr_svg, nil)
      |> assign(:totp_secret_b32, nil)

    {:noreply, socket}
  end

  def handle_event("verify_totp_setup", %{"totp" => %{"code" => code}}, socket) do
    customer = socket.assigns.current_scope.customer
    secret = socket.assigns.pending_totp_secret

    if Customers.valid_totp_code?(secret, code) do
      case Customers.enable_totp(customer, secret) do
        {:ok, _updated_customer} ->
          codes = Customers.generate_recovery_codes(customer)

          socket =
            socket
            |> assign(:pending_totp_secret, nil)
            |> assign(:totp_qr_svg, nil)
            |> assign(:totp_secret_b32, nil)
            |> assign(:show_recovery_codes, true)
            |> assign(:recovery_codes, codes)
            |> assign(:remaining_recovery_codes, length(codes))

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply,
           put_flash(socket, :error, "Failed to enable authenticator. Please try again.")}
      end
    else
      totp_verify_form = to_form(%{"code" => code}, as: :totp)

      socket =
        socket
        |> put_flash(:error, "Invalid code. Please try again.")
        |> assign(:totp_verify_form, totp_verify_form)

      {:noreply, socket}
    end
  end

  def handle_event("disable_totp", _params, socket) do
    customer = socket.assigns.current_scope.customer

    case Customers.disable_totp(customer) do
      {:ok, _updated_customer} ->
        {:noreply, put_flash(socket, :info, "Authenticator app disabled.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to disable authenticator.")}
    end
  end

  def handle_event("confirm_codes_saved", _params, socket) do
    socket =
      socket
      |> assign(:show_recovery_codes, false)
      |> assign(:recovery_codes, [])
      |> put_flash(:info, "Two-factor authentication enabled successfully.")

    {:noreply, socket}
  end

  # ── Recovery Codes ──────────────────────────────────────────────────────────

  def handle_event("regenerate_recovery_codes", _params, socket) do
    customer = socket.assigns.current_scope.customer
    codes = Customers.generate_recovery_codes(customer)

    socket =
      socket
      |> assign(:show_recovery_codes, true)
      |> assign(:recovery_codes, codes)
      |> assign(:remaining_recovery_codes, length(codes))

    {:noreply, socket}
  end

  # ── WebAuthn ────────────────────────────────────────────────────────────────

  def handle_event("add_webauthn_key", _params, socket) do
    {:noreply, assign(socket, :adding_webauthn_key, true)}
  end

  def handle_event("cancel_webauthn_registration", _params, socket) do
    socket =
      socket
      |> assign(:adding_webauthn_key, false)
      |> assign(:webauthn_registration_challenge, nil)
      |> assign(:webauthn_label_form, to_form(%{"label" => ""}, as: :webauthn))

    {:noreply, socket}
  end

  def handle_event("start_webauthn_registration", %{"webauthn" => %{"label" => label}}, socket) do
    customer = socket.assigns.current_scope.customer
    {challenge, opts} = Customers.webauthn_registration_options(customer)

    socket =
      socket
      |> assign(:webauthn_registration_challenge, challenge)
      |> assign(:webauthn_pending_label, label)
      |> push_event("webauthn_register_options", opts)

    {:noreply, socket}
  end

  def handle_event("webauthn_registered", %{"credential" => credential_json}, socket) do
    customer = socket.assigns.current_scope.customer
    challenge = socket.assigns.webauthn_registration_challenge
    label = socket.assigns[:webauthn_pending_label] || "Security Key"

    case Customers.register_webauthn_credential(customer, challenge, credential_json, label) do
      {:ok, _credential} ->
        credentials = Customers.list_webauthn_credentials(customer)

        socket =
          socket
          |> assign(:webauthn_credentials, credentials)
          |> assign(:adding_webauthn_key, false)
          |> assign(:webauthn_registration_challenge, nil)
          |> assign(:webauthn_label_form, to_form(%{"label" => ""}, as: :webauthn))
          |> put_flash(:info, "Security key added successfully.")

        {:noreply, socket}

      {:error, _reason} ->
        socket =
          socket
          |> assign(:webauthn_registration_challenge, nil)
          |> put_flash(:error, "Failed to register security key. Please try again.")

        {:noreply, socket}
    end
  end

  def handle_event("webauthn_error", %{"error" => message}, socket) do
    socket =
      socket
      |> assign(:webauthn_registration_challenge, nil)
      |> put_flash(:error, "Security key error: #{message}")

    {:noreply, socket}
  end

  def handle_event("delete_webauthn_credential", %{"id" => id_str}, socket) do
    customer = socket.assigns.current_scope.customer
    id = String.to_integer(id_str)

    credential =
      Enum.find(socket.assigns.webauthn_credentials, fn c -> c.id == id end)

    if credential && credential.customer_id == customer.id do
      Pretex.Repo.delete!(credential)
      credentials = Customers.list_webauthn_credentials(customer)

      socket =
        socket
        |> assign(:webauthn_credentials, credentials)
        |> put_flash(:info, "Security key removed.")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Security key not found.")}
    end
  end
end
