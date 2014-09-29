require "elasticity/search"

RSpec.describe Elasticity::Search do
  let(:index)          { double(:index) }
  let(:document_klass) { double(:document_klass) }
  let(:body)           { double(:body) }

  subject do
    described_class.new(index, "document", document_klass, body)
  end
end
