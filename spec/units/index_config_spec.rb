require 'elasticity/index_config'

RSpec.describe Elasticity::IndexConfig do
  let(:elasticity_config) { double }
  subject {  }

    let(:defaults) do
      {
        index_base_name: 'users',
        document_type: 'user'
      }
    end

  it 'accepts default configuration options' do
    config = described_class.new(elasticity_config, defaults) {}
    expect(config.index_base_name).to eql('users')
    expect(config.document_type).to eql('user')
  end

  it 'overrides defaults' do
    config = described_class.new(elasticity_config, defaults) do |c|
      c.index_base_name = 'user_documents'
      c.document_type = 'users'
    end

    expect(config.index_base_name).to eql('user_documents')
    expect(config.document_type).to eql('users')
  end
end
