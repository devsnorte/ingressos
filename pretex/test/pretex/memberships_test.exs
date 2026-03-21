defmodule Pretex.MembershipsTest do
  use Pretex.DataCase, async: true

  import Pretex.OrganizationsFixtures
  import Pretex.CustomersFixtures

  alias Pretex.Memberships

  # ---------------------------------------------------------------------------
  # MembershipType CRUD
  # ---------------------------------------------------------------------------

  describe "create_membership_type/2" do
    test "creates a membership type for an org" do
      org = org_fixture()

      assert {:ok, mt} =
               Memberships.create_membership_type(org, %{
                 name: "Gold Member",
                 validity_days: 365,
                 description: "Premium benefits"
               })

      assert mt.name == "Gold Member"
      assert mt.validity_days == 365
      assert mt.organization_id == org.id
      assert mt.active == true
    end

    test "rejects invalid data" do
      org = org_fixture()
      assert {:error, changeset} = Memberships.create_membership_type(org, %{name: ""})
      assert errors_on(changeset).name != []
      assert errors_on(changeset).validity_days != []
    end
  end

  describe "list_membership_types/1" do
    test "lists all types for an org" do
      org = org_fixture()
      {:ok, _mt1} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})
      {:ok, _mt2} = Memberships.create_membership_type(org, %{name: "Silver", validity_days: 180})

      types = Memberships.list_membership_types(org)
      assert length(types) == 2
    end

    test "does not include types from other orgs" do
      org1 = org_fixture()
      org2 = org_fixture()
      {:ok, _mt} = Memberships.create_membership_type(org1, %{name: "Gold", validity_days: 365})

      assert Memberships.list_membership_types(org2) == []
    end
  end

  describe "update_membership_type/2" do
    test "updates a membership type" do
      org = org_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      assert {:ok, updated} = Memberships.update_membership_type(mt, %{name: "Platinum"})
      assert updated.name == "Platinum"
    end
  end

  # ---------------------------------------------------------------------------
  # MembershipBenefit CRUD
  # ---------------------------------------------------------------------------

  describe "create_benefit/2" do
    test "creates a percentage discount benefit" do
      org = org_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      assert {:ok, benefit} =
               Memberships.create_benefit(mt, %{benefit_type: "percentage_discount", value: 1500})

      assert benefit.benefit_type == "percentage_discount"
      assert benefit.value == 1500
      assert benefit.membership_type_id == mt.id
    end

    test "creates a fixed discount benefit" do
      org = org_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      assert {:ok, benefit} =
               Memberships.create_benefit(mt, %{benefit_type: "fixed_discount", value: 2000})

      assert benefit.benefit_type == "fixed_discount"
      assert benefit.value == 2000
    end

    test "creates an item_access benefit (no value required)" do
      org = org_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      assert {:ok, benefit} = Memberships.create_benefit(mt, %{benefit_type: "item_access"})
      assert benefit.benefit_type == "item_access"
    end

    test "rejects invalid benefit type" do
      org = org_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      assert {:error, changeset} = Memberships.create_benefit(mt, %{benefit_type: "bogus"})
      assert errors_on(changeset).benefit_type != []
    end

    test "rejects percentage > 100%" do
      org = org_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      assert {:error, changeset} =
               Memberships.create_benefit(mt, %{
                 benefit_type: "percentage_discount",
                 value: 10_001
               })

      assert errors_on(changeset).value != []
    end
  end

  # ---------------------------------------------------------------------------
  # Grant / Activate Membership
  # ---------------------------------------------------------------------------

  describe "grant_membership/4" do
    test "grants a membership to a customer" do
      org = org_fixture()
      customer = customer_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      assert {:ok, membership} = Memberships.grant_membership(mt, customer, org)

      assert membership.customer_id == customer.id
      assert membership.organization_id == org.id
      assert membership.membership_type_id == mt.id
      assert membership.status == "active"
      assert membership.source_order_id == nil
      assert DateTime.diff(membership.expires_at, membership.starts_at, :day) >= 364
    end
  end

  describe "list_active_memberships/1" do
    test "returns only active memberships for a customer" do
      org = org_fixture()
      customer = customer_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, _active} = Memberships.grant_membership(mt, customer, org)

      memberships = Memberships.list_active_memberships(customer)
      assert length(memberships) == 1
      assert hd(memberships).status == "active"
    end

    test "excludes expired memberships" do
      org = org_fixture()
      customer = customer_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, m} = Memberships.grant_membership(mt, customer, org)
      Memberships.expire_membership(m)

      assert Memberships.list_active_memberships(customer) == []
    end
  end

  describe "active_memberships_for_checkout/2" do
    test "returns active memberships for customer+org with benefits preloaded" do
      org = org_fixture()
      customer = customer_fixture()
      {:ok, mt} = Memberships.create_membership_type(org, %{name: "Gold", validity_days: 365})

      {:ok, _b} =
        Memberships.create_benefit(mt, %{benefit_type: "percentage_discount", value: 1500})

      {:ok, _m} = Memberships.grant_membership(mt, customer, org)

      memberships = Memberships.active_memberships_for_checkout(customer, org)
      assert length(memberships) == 1

      [m] = memberships
      assert length(m.membership_type.benefits) == 1
    end

    test "ignores memberships from another org" do
      org1 = org_fixture()
      org2 = org_fixture()
      customer = customer_fixture()
      {:ok, mt} = Memberships.create_membership_type(org1, %{name: "Gold", validity_days: 365})
      {:ok, _m} = Memberships.grant_membership(mt, customer, org1)

      assert Memberships.active_memberships_for_checkout(customer, org2) == []
    end
  end
end
