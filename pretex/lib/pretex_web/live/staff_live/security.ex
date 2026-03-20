defmodule PretexWeb.StaffLive.Security do
  use PretexWeb, :live_view

  on_mount({PretexWeb.UserAuth, :require_authenticated_user})

  alias Pretex.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <nav class="navbar bg-base-100 border-b border-base-300">
        <div class="container mx-auto px-4 flex items-center justify-between">
          <a href="/" class="flex items-center gap-2">
            <div class="w-8 h-8 rounded-lg bg-primary flex items-center justify-center">
              <.icon name="hero-ticket" class="w-4 h-4 text-primary-content" />
            </div>
            <span class="font-bold">Pretex</span>
          </a>
          <.link href="/staff/log-out" method="delete" class="btn btn-ghost btn-sm">Sair</.link>
        </div>
      </nav>

      <main class="container mx-auto px-4 py-8 max-w-3xl">
        <Layouts.flash_group flash={@flash} />

        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold">Configurações de Segurança</h1>
          <p class="mt-1 text-sm text-base-content/60">
            Gerencie a autenticação em duas etapas da sua conta staff
          </p>
        </div>

        <%!-- TOTP Section --%>
        <div id="totp-section" class="card bg-base-100 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-lg">Aplicativo Autenticador</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Use um aplicativo autenticador para gerar códigos únicos de segurança extra.
            </p>

            <%= if @show_recovery_codes do %>
              <div
                id="recovery-codes-reveal"
                class="rounded-2xl bg-warning/10 border border-warning/30 p-6"
              >
                <div class="flex items-center gap-2 mb-3">
                  <.icon name="hero-key" class="w-5 h-5 text-warning" />
                  <h3 class="font-semibold">Salve seus códigos de recuperação</h3>
                </div>
                <p class="text-sm text-base-content/70 mb-4">
                  Guarde esses códigos em um lugar seguro. Cada código só pode ser usado uma vez.
                  Se você perder o acesso ao autenticador, poderá usá-los para entrar.
                </p>
                <div id="recovery-codes-list" class="grid grid-cols-2 gap-2 mb-4">
                  <%= for code <- @recovery_codes do %>
                    <code class="font-mono text-sm bg-base-100 border border-warning/30 rounded-lg px-3 py-2 text-center">
                      {code}
                    </code>
                  <% end %>
                </div>
                <.button
                  id="confirm-codes-saved"
                  variant="primary"
                  phx-click="confirm_codes_saved"
                >
                  Já salvei esses códigos
                </.button>
              </div>
            <% else %>
              <%= if @pending_totp_secret do %>
                <div id="totp-setup" class="rounded-2xl border border-base-300 bg-base-100 p-6">
                  <h3 class="font-semibold mb-3">Escaneie o QR Code</h3>
                  <p class="text-sm text-base-content/60 mb-4">
                    Escaneie este QR Code com seu aplicativo autenticador (Google Authenticator,
                    Authy, etc.), depois digite o código de 6 dígitos abaixo para confirmar.
                  </p>
                  <div id="totp-qr" class="flex justify-center mb-4">
                    {Phoenix.HTML.raw(@totp_qr_svg)}
                  </div>
                  <p class="text-xs text-base-content/50 mb-1">Ou insira esta chave manualmente:</p>
                  <code
                    id="totp-secret-b32"
                    class="block font-mono text-sm bg-base-200 border border-base-300 rounded-lg px-3 py-2 text-center mb-4 break-all"
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
                      label="Código de verificação"
                      placeholder="000000"
                      autocomplete="one-time-code"
                      inputmode="numeric"
                      maxlength="6"
                      required
                    />
                    <div class="flex gap-2 mt-4">
                      <.button variant="primary" phx-disable-with="Verificando...">
                        Ativar Autenticador
                      </.button>
                      <.button id="cancel-totp-setup" phx-click="cancel_totp_setup" type="button">
                        Cancelar
                      </.button>
                    </div>
                  </.form>
                </div>
              <% else %>
                <%= if Accounts.User.totp_enabled?(@current_user) do %>
                  <div
                    id="totp-enabled-badge"
                    class="flex items-center justify-between rounded-2xl border border-success/30 bg-success/10 p-4"
                  >
                    <div class="flex items-center gap-3">
                      <div class="flex h-8 w-8 items-center justify-center rounded-full bg-success/20">
                        <.icon name="hero-check" class="w-4 h-4 text-success" />
                      </div>
                      <div>
                        <p class="text-sm font-semibold">Aplicativo Autenticador ativado</p>
                        <p class="text-xs text-base-content/60">Sua conta está protegida com TOTP.</p>
                      </div>
                    </div>
                    <.button
                      id="disable-totp-btn"
                      phx-click="disable_totp"
                      data-confirm="Tem certeza que deseja desativar a autenticação em duas etapas?"
                    >
                      Desativar
                    </.button>
                  </div>
                <% else %>
                  <.button
                    id="enable-totp-btn"
                    variant="primary"
                    phx-click="start_totp_setup"
                  >
                    <.icon name="hero-qr-code" class="w-4 h-4 mr-1" /> Ativar Aplicativo Autenticador
                  </.button>
                <% end %>
              <% end %>
            <% end %>
          </div>
        </div>

        <%!-- Recovery Codes Section --%>
        <div id="recovery-codes-section" class="card bg-base-100 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-lg">Códigos de Recuperação</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Os códigos de recuperação permitem acessar sua conta caso você perca o autenticador.
              Você tem <strong>{@remaining_recovery_codes}</strong> códigos não utilizados restantes.
            </p>
            <div>
              <.button
                id="regenerate-codes-btn"
                phx-click="regenerate_recovery_codes"
                data-confirm="Isso invalidará todos os códigos de recuperação existentes. Continuar?"
              >
                <.icon name="hero-arrow-path" class="w-4 h-4 mr-1" /> Gerar novos códigos
              </.button>
            </div>
          </div>
        </div>

        <%!-- WebAuthn Section --%>
        <div
          id="webauthn-register-hook"
          phx-hook=".WebAuthnRegister"
          phx-update="ignore"
        >
        </div>

        <div id="webauthn-section" class="card bg-base-100 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-lg">Chaves de Segurança</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Adicione uma chave de segurança de hardware (ex: YubiKey) ou uma passkey para proteção adicional.
            </p>

            <%= if @webauthn_credentials == [] do %>
              <p id="no-webauthn-keys" class="text-sm text-base-content/40 italic mb-4">
                Nenhuma chave de segurança registrada.
              </p>
            <% else %>
              <ul id="webauthn-credentials-list" class="space-y-2 mb-4">
                <%= for cred <- @webauthn_credentials do %>
                  <li
                    id={"webauthn-cred-#{cred.id}"}
                    class="flex items-center justify-between rounded-xl border border-base-300 bg-base-100 px-4 py-3"
                  >
                    <div class="flex items-center gap-3">
                      <.icon name="hero-key" class="w-5 h-5 text-base-content/40" />
                      <div>
                        <p class="text-sm font-medium">
                          {cred.label || "Chave de Segurança"}
                        </p>
                        <%= if cred.last_used_at do %>
                          <p class="text-xs text-base-content/40">Último uso: {cred.last_used_at}</p>
                        <% else %>
                          <p class="text-xs text-base-content/40">Nunca utilizada</p>
                        <% end %>
                      </div>
                    </div>
                    <.button
                      id={"delete-webauthn-#{cred.id}"}
                      phx-click="delete_webauthn_credential"
                      phx-value-id={cred.id}
                      data-confirm="Remover esta chave de segurança?"
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
                class="rounded-2xl border border-base-300 bg-base-100 p-6 mb-4"
              >
                <h3 class="font-semibold mb-3">Nomeie sua chave de segurança</h3>
                <.form
                  for={@webauthn_label_form}
                  id="webauthn-label-form-inner"
                  phx-submit="start_webauthn_registration"
                >
                  <.input
                    field={@webauthn_label_form[:label]}
                    type="text"
                    label="Nome da chave (ex: YubiKey 5)"
                    placeholder="Minha Chave de Segurança"
                    required
                  />
                  <div class="flex gap-2 mt-4">
                    <.button
                      id="confirm-webauthn-label"
                      variant="primary"
                      phx-disable-with="Aguardando a chave..."
                    >
                      Continuar
                    </.button>
                    <.button
                      id="cancel-webauthn-add"
                      phx-click="cancel_webauthn_registration"
                      type="button"
                    >
                      Cancelar
                    </.button>
                  </div>
                </.form>
              </div>
            <% else %>
              <.button id="add-webauthn-btn" phx-click="add_webauthn_key">
                <.icon name="hero-plus" class="w-4 h-4 mr-1" /> Adicionar chave de segurança
              </.button>
            <% end %>
          </div>
        </div>
      </main>

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
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    webauthn_credentials = Accounts.list_webauthn_credentials(user)
    remaining = Accounts.remaining_recovery_codes(user)

    socket =
      socket
      |> assign(:page_title, "Security Settings")
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

  # ── TOTP ────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("start_totp_setup", _params, socket) do
    user = socket.assigns.current_user
    secret = Accounts.generate_totp_secret()
    qr_svg = Accounts.totp_qr_svg(user, secret)
    b32 = Accounts.totp_secret_base32(secret)

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
    user = socket.assigns.current_user
    secret = socket.assigns.pending_totp_secret

    if Accounts.valid_totp_code?(secret, code) do
      case Accounts.enable_totp(user, secret) do
        {:ok, _updated_user} ->
          codes = Accounts.generate_recovery_codes(user)

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
    user = socket.assigns.current_user

    case Accounts.disable_totp(user) do
      {:ok, _updated_user} ->
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
    user = socket.assigns.current_user
    codes = Accounts.generate_recovery_codes(user)

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
    user = socket.assigns.current_user
    {challenge, opts} = Accounts.webauthn_registration_options(user)

    socket =
      socket
      |> assign(:webauthn_registration_challenge, challenge)
      |> assign(:webauthn_pending_label, label)
      |> push_event("webauthn_register_options", opts)

    {:noreply, socket}
  end

  def handle_event("webauthn_registered", %{"credential" => credential_json}, socket) do
    user = socket.assigns.current_user
    challenge = socket.assigns.webauthn_registration_challenge
    label = socket.assigns[:webauthn_pending_label] || "Security Key"

    case Accounts.register_webauthn_credential(user, challenge, credential_json, label) do
      {:ok, _credential} ->
        credentials = Accounts.list_webauthn_credentials(user)

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
    user = socket.assigns.current_user
    id = String.to_integer(id_str)

    credential =
      Enum.find(socket.assigns.webauthn_credentials, fn c -> c.id == id end)

    if credential && credential.user_id == user.id do
      Pretex.Repo.delete!(credential)
      credentials = Accounts.list_webauthn_credentials(user)

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
