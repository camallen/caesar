require 'spec_helper'

describe Effects::AddSubjectToCollection do
  let(:workflow_id) { 10 }
  let(:subject_id){ 20 }
  let(:collection_id){ 1234 }

  let(:panoptes) { double("PanoptesAdapter", add_subjects_to_collection: true) }
  let(:effect) { described_class.new("collection_id" => collection_id) }

  before do
    allow(Effects).to receive(:panoptes).and_return(panoptes)
  end

  it 'adds the given subject to a given subject set' do
    effect.perform(workflow_id, subject_id)
    expect(panoptes).to have_received(:add_subjects_to_collection)
      .with(collection_id, [subject_id])
  end
end
