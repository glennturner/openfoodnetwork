# frozen_string_literal: true

require "system_helper"

describe "Orders And Fulfillment" do
  include AuthenticationHelper
  include WebHelper

  describe "reports" do
    before do
      login_as_admin
      visit admin_reports_path
    end

    let(:bill_address1) { create(:address, lastname: "ABRA") }
    let(:bill_address2) { create(:address, lastname: "KADABRA") }
    let(:distributor_address) {
      create(:address, address1: "distributor address", city: 'The Shire', zipcode: "1234")
    }
    let(:distributor) { create(:distributor_enterprise, address: distributor_address) }
    let(:order_cycle) { create(:simple_order_cycle, distributors: [distributor]) }
    let(:order1) {
      create(:completed_order_with_totals, line_items_count: 0, distributor: distributor,
                                           bill_address: bill_address1,
                                           order_cycle_id: order_cycle.id)
    }
    let(:order2) {
      create(:completed_order_with_totals, line_items_count: 0, distributor: distributor,
                                           bill_address: bill_address1,
                                           order_cycle_id: order_cycle.id)
    }
    let(:supplier) { create(:supplier_enterprise, name: "Supplier Name") }
    let(:product) { create(:simple_product, name: "Baked Beans", supplier: supplier ) }
    let(:variant1) { create(:variant, product: product, unit_description: "Big") }
    let(:variant2) { create(:variant, product: product, unit_description: "Small") }

    before do
      # order1 has two line items / variants
      create(:line_item_with_shipment, variant: variant1, quantity: 1, order: order1)
      create(:line_item_with_shipment, variant: variant2, quantity: 3, order: order1)
      # order2 has one line items / variants
      create(:line_item_with_shipment, variant: variant1, quantity: 2, order: order2)
    end

    describe "Order Cycle Customer Totals" do
      before do
        click_link "Order Cycle Customer Totals"
      end

      it "displays the report" do
        click_button 'Go'

        rows = find("table.report__table").all("thead tr")
        table = rows.map { |r| r.all("th").map { |c| c.text.strip } }
        expect(table).to eq([
                              ["Hub",
                               "Customer",
                               "Email",
                               "Phone",
                               "Producer",
                               "Product",
                               "Variant",
                               "Quantity",
                               "Item ($)",
                               "Item + Fees ($)",
                               "Admin & Handling ($)",
                               "Ship ($)",
                               "Pay fee ($)",
                               "Total ($)",
                               "Paid?",
                               "Shipping",
                               "Delivery?",
                               "Ship Street",
                               "Ship Street 2",
                               "Ship City",
                               "Ship Postcode",
                               "Ship State",
                               "Comments",
                               "SKU",
                               "Order Cycle",
                               "Payment Method",
                               "Customer Code",
                               "Tags",
                               "Billing Street",
                               "Billing Street 2",
                               "Billing City",
                               "Billing Postcode",
                               "Billing State",
                               "Order number",
                               "Date"]
                               .map(&:upcase)
                            ])
      end

      context "order cycles with nil opening or closing times" do
        before do
          order_cycle.update!(orders_open_at: Time.zone.now, orders_close_at: nil,
                              name: "My Order Cycle")
        end

        it "correclty renders the report" do
          click_button 'Go'
          expect(page).to have_content "My Order Cycle"
        end
      end

      context "with two orders on the same day at different times" do
        let(:completed_at1) { Time.zone.now - 1500.hours } # 1500 hours in the past
        let(:completed_at2) { Time.zone.now - 1700.hours } # 1700 hours in the past
        let(:datetime_start1) { Time.zone.now - 1600.hours } # 1600 hours in the past
        let(:datetime_start2) { Time.zone.now - 1800.hours } # 1600 hours in the past
        let(:datetime_end) { Time.zone.now - 1400.hours } # 1400 hours in the past
        before do
          Timecop.travel(completed_at1) { order1.finalize! }
          Timecop.travel(completed_at2) { order2.finalize! }
        end

        it "is precise to time of day, not just date" do
          # When I generate a customer report
          # with a timeframe that includes one order but not the other
          pick_datetime "#q_completed_at_gt", datetime_start1
          pick_datetime "#q_completed_at_lt", datetime_end

          find("#display_summary_row").set(false) # hides the summary rows
          click_button 'Go'
          # Then I should see the rows for the first order but not the second
          # One row per line item - order1 only
          expect(all('table.report__table tbody tr').count).to eq(2)

          find("#display_summary_row").set(true) # displays the summary rows
          click_button 'Go'
          # Then I should see the rows for the first order but not the second
          expect(all('table.report__table tbody tr').count).to eq(3)
          # 2 rows for order1 + 1 summary row

          # setting a time interval to include both orders
          pick_datetime "#q_completed_at_gt", datetime_start2
          click_button 'Go'
          # Then I should see the rows for both orders
          expect(all('table.report__table tbody tr').count).to eq(5)
          # 2 rows for order1 + 1 summary row
          # 1 row for order2 + 1 summary row
        end
      end
    end

    describe "Order Cycle Supplier Totals" do
      before do
        click_link "Order Cycle Supplier Totals"
      end

      context "with the header row option not selected" do
        before do
          find("#display_header_row").set(false) # hides the header row
        end

        it "displays the report" do
          click_button 'Go'

          rows = find("table.report__table").all("thead tr")
          table = rows.map { |r| r.all("th").map { |c| c.text.strip } }

          # displays the producer column
          expect(table).to eq([
                                ["Producer",
                                 "Product",
                                 "Variant",
                                 "Quantity",
                                 "Total Units",
                                 "Curr. Cost per Unit",
                                 "Total Cost"]
                                 .map(&:upcase)
                              ])

          # displays the producer name in the respective column
          # does not display the header row
          within "td" do
            expect(page).to have_content("Supplier Name")
            expect(page).not_to have_css("td.header-row")
          end
        end
      end

      context "with the header row option selected" do
        before do
          find("#display_header_row").set(true) # displays the header row
        end

        it "displays the report" do
          click_button 'Go'

          rows = find("table.report__table").all("thead tr")
          table = rows.map { |r| r.all("th").map { |c| c.text.strip } }

          # hides the producer column
          expect(table).to eq([
                                ["Product",
                                 "Variant",
                                 "Quantity",
                                 "Total Units",
                                 "Curr. Cost per Unit",
                                 "Total Cost"]
                                 .map(&:upcase)
                              ])

          # displays the producer name in own row
          within "td.header-row" do
            expect(page).to have_content("Supplier Name")
          end
        end
      end

      context "for two different orders" do
        let(:order3) {
          create(:completed_order_with_totals, line_items_count: 0,
                                               distributor: distributor,
                                               bill_address: bill_address1,
                                               order_cycle_id: order_cycle.id)
        }

        before do
          create(:line_item_with_shipment, variant: variant2, quantity: 4, order: order1)
          order3.finalize!
          click_button 'Go'
        end

        it "aggregates results per variant" do
          expect(all('table.report__table tbody tr').count).to eq(3)
          # 1 row per variant = 2 rows
          # 1 summary row
          # 3 rows total

          rows = find("table.report__table").all("tbody tr")
          table = rows.map { |r| r.all("td").map { |c| c.text.strip } }

          expect(table[0]).to eq([
                                   "Supplier Name",
                                   "Baked Beans",
                                   "1g Big, S",
                                   "3",
                                   "0.003",
                                   "10.0",
                                   "30.0"
                                 ])

          expect(table[1]).to eq([
                                   "Supplier Name",
                                   "Baked Beans",
                                   "1g Small, S",
                                   "7",
                                   "0.007",
                                   "10.0",
                                   "70.0"
                                 ])
          expect(table[2]).to eq([
                                   "",
                                   "",
                                   "TOTAL",
                                   "10",
                                   "0.01",
                                   "",
                                   "100.0"
                                 ])
        end
      end
    end

    describe "Order Cycle Supplier Totals by Distributor" do
      before do
        click_link "Order Cycle Supplier Totals by Distributor"
      end

      it "displays the report" do
        click_button 'Go'

        rows = find("table.report__table").all("thead tr")
        table = rows.map { |r| r.all("th").map { |c| c.text.strip } }
        expect(table).to eq([
                              ["Producer",
                               "Product",
                               "Variant",
                               "Hub",
                               "Quantity",
                               "Curr. Cost per Unit",
                               "Total Cost",
                               "Shipping Method"]
                               .map(&:upcase)
                            ])
      end
    end

    describe "Order Cycle Distributor Totals by Supplier" do
      before do
        click_link "Order Cycle Distributor Totals by Supplier"
      end

      it "displays the report" do
        click_button 'Go'

        rows = find("table.report__table").all("thead tr")
        table = rows.map { |r| r.all("th").map { |c| c.text.strip } }
        expect(table).to eq([
                              ["Hub",
                               "Producer",
                               "Product",
                               "Variant",
                               "Quantity",
                               "Curr. Cost per Unit",
                               "Total Cost",
                               "Total Shipping Cost",
                               "Shipping Method"]
                               .map(&:upcase)
                            ])
      end
    end
  end
end
