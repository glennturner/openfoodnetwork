# frozen_string_literal: true

require 'spec_helper'

describe Vouchers::PercentageRate do
  let(:enterprise) { build(:enterprise) }

  describe 'validations' do
    subject { build(:voucher_percentage_rate, code: 'new_code', enterprise: enterprise) }

    it { is_expected.to validate_presence_of(:amount) }
    it do
      is_expected.to validate_numericality_of(:amount)
        .is_greater_than(0)
        .is_less_than_or_equal_to(100)
    end
  end

  describe '#compute_amount' do
    subject do
      create(:voucher_percentage_rate, code: 'new_code', enterprise: enterprise, amount: 10)
    end
    let(:order) { create(:order_with_totals) }

    it 'returns percentage of the order total' do
      expect(subject.compute_amount(order)).to eq(-order.pre_discount_total * 0.1)
    end
  end
end
