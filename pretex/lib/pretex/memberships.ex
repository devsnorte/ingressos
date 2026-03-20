defmodule Pretex.Memberships do
  @moduledoc "Manages membership types, benefits, and customer memberships."

  import Ecto.Query

  alias Pretex.Repo
  alias Pretex.Memberships.MembershipType
  alias Pretex.Memberships.MembershipBenefit
  alias Pretex.Memberships.Membership
  alias Pretex.Memberships.OrderMembershipDiscount
  alias Pretex.Orders.Order

  # ---------------------------------------------------------------------------
  # MembershipType CRUD
  # ---------------------------------------------------------------------------

  def list_membership_types(%{id: org_id}) do
    MembershipType
    |> where([mt], mt.organization_id == ^org_id)
    |> order_by([mt], asc: mt.name)
    |> preload(:benefits)
    |> Repo.all()
  end

  def get_membership_type!(id) do
    MembershipType
    |> preload(:benefits)
    |> Repo.get!(id)
  end

  def create_membership_type(%{id: org_id}, attrs) do
    %MembershipType{}
    |> MembershipType.changeset(attrs)
    |> Ecto.Changeset.put_change(:organization_id, org_id)
    |> Repo.insert()
  end

  def update_membership_type(%MembershipType{} = mt, attrs) do
    mt
    |> MembershipType.changeset(attrs)
    |> Repo.update()
  end

  def delete_membership_type(%MembershipType{} = mt) do
    Repo.delete(mt)
  end

  # ---------------------------------------------------------------------------
  # MembershipBenefit CRUD
  # ---------------------------------------------------------------------------

  def create_benefit(%MembershipType{id: mt_id}, attrs) do
    %MembershipBenefit{}
    |> MembershipBenefit.changeset(attrs)
    |> Ecto.Changeset.put_change(:membership_type_id, mt_id)
    |> Repo.insert()
  end

  def delete_benefit(%MembershipBenefit{} = benefit) do
    Repo.delete(benefit)
  end

  # ---------------------------------------------------------------------------
  # Membership grant / management
  # ---------------------------------------------------------------------------

  def grant_membership(%MembershipType{} = mt, customer, org, attrs \\ %{}) do
    now = DateTime.utc_now(:second)
    expires_at = DateTime.add(now, mt.validity_days * 86_400, :second)

    %Membership{}
    |> Membership.changeset(
      Map.merge(
        %{
          starts_at: now,
          expires_at: expires_at,
          status: "active",
          membership_type_id: mt.id,
          customer_id: customer.id,
          organization_id: org.id
        },
        attrs
      )
    )
    |> Repo.insert()
  end

  def activate_membership_from_order(%MembershipType{} = mt, customer, org, order) do
    grant_membership(mt, customer, org, %{source_order_id: order.id})
  end

  def expire_membership(%Membership{} = m) do
    m
    |> Ecto.Changeset.change(status: "expired")
    |> Repo.update()
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  def list_active_memberships(customer) do
    Membership
    |> where([m], m.customer_id == ^customer.id and m.status == "active")
    |> preload(membership_type: :benefits)
    |> Repo.all()
  end

  def active_memberships_for_checkout(customer, %{id: org_id}) do
    now = DateTime.utc_now(:second)

    Membership
    |> where([m],
      m.customer_id == ^customer.id and
        m.organization_id == ^org_id and
        m.status == "active" and
        m.expires_at > ^now
    )
    |> preload(membership_type: :benefits)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Checkout: evaluate and apply best membership discount
  # ---------------------------------------------------------------------------

  @doc """
  Evaluate all active membership discount benefits for a customer+org and
  return the best one. Returns {:ok, %{membership: m, benefit: b, discount_cents: int}}
  or {:error, :no_membership_discount}.
  """
  def best_membership_discount(customer_id, org_id, subtotal_cents) do
    now = DateTime.utc_now(:second)

    memberships =
      Membership
      |> where([m],
        m.customer_id == ^customer_id and
          m.organization_id == ^org_id and
          m.status == "active" and
          m.expires_at > ^now
      )
      |> preload(membership_type: :benefits)
      |> Repo.all()

    discount_benefits =
      memberships
      |> Enum.flat_map(fn m ->
        m.membership_type.benefits
        |> Enum.filter(&(&1.benefit_type in ["percentage_discount", "fixed_discount"]))
        |> Enum.map(fn b ->
          discount_cents = compute_benefit_discount(b, subtotal_cents)
          %{membership: m, benefit: b, discount_cents: discount_cents}
        end)
      end)
      |> Enum.sort_by(& &1.discount_cents, :desc)

    case discount_benefits do
      [] -> {:error, :no_membership_discount}
      [best | _] -> {:ok, best}
    end
  end

  @doc """
  Apply the best membership discount to an order. Inserts an
  OrderMembershipDiscount record and updates order.total_cents.
  Uses bare Repo operations (no nested transaction).
  """
  def apply_best_membership_discount(%Order{} = order, customer_id, org_id) do
    case best_membership_discount(customer_id, org_id, order.total_cents) do
      {:error, :no_membership_discount} ->
        {:ok, order}

      {:ok, %{membership: m, benefit: b, discount_cents: discount_cents}} ->
        capped = min(discount_cents, order.total_cents)

        changeset =
          %OrderMembershipDiscount{}
          |> OrderMembershipDiscount.changeset(%{
            name: m.membership_type.name,
            discount_cents: capped,
            value_type: b.benefit_type |> String.replace("_discount", ""),
            value: b.value,
            order_id: order.id,
            membership_id: m.id
          })

        case Repo.insert(changeset) do
          {:ok, _} ->
            new_total = max(0, order.total_cents - capped)

            updated =
              order
              |> Ecto.Changeset.change(total_cents: new_total)
              |> Repo.update!()

            {:ok, updated}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp compute_benefit_discount(%{benefit_type: "fixed_discount", value: value}, subtotal_cents) do
    min(value, subtotal_cents)
  end

  defp compute_benefit_discount(%{benefit_type: "percentage_discount", value: basis_points}, subtotal_cents) do
    round(subtotal_cents * basis_points / 10_000)
  end

  defp compute_benefit_discount(_, _), do: 0
end
