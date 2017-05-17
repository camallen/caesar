require 'spec_helper'

describe Conditions::Any do
  def make_rule(reducer_id, compare_operation, compare_constant)
    described_class.new(
      reducer_id,
      Conditions::Comparison.new(
        compare_operation, [
          Conditions::Lookup.new('value', 0),
          Conditions::Constant.new(compare_constant)
        ]
      )
    )
  end

  let(:reductions){
    [
      Reduction.new(reducer_id: 'savannah', data: {:serval => 1, :hippo => 1, :cerulean => 1}),
      Reduction.new(reducer_id: 'mountain', data: {:ibis => 1, :alpaca => 1, :cerulean => 5})
    ]
  }

  let(:bindings){
    RuleBindings.new(reductions)
  }

  it('throws an error on empty bindings') do
    rule = make_rule('friends', 'gte', 5)
    expect {
      rule.apply(nil)
    }.to raise_error(NoMethodError)
  end

  it('throws an error on bindings that lack the requested dictionary') do
    rule = make_rule('friends', 'gte', 5)
    expect {
      rule.apply(bindings)
    }.to raise_error(KeyError)
  end

  it('is false when there are less than 5 of every critter') do
    rule = make_rule('savannah', 'gte', 5)
    result = rule.apply(bindings)
    expect(result).to be(false)
  end

  it('is true when there are more than 5 of a critter') do
    rule = make_rule('mountain', 'gte', 5)
    result = rule.apply(bindings)
    expect(result).to be(true)
  end
end