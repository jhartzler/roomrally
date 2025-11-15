require 'rails_helper'
require 'rake'

RSpec.describe 'db:seed', type: :task do
  before do
    Prompt.destroy_all
    load Rails.root.join('db', 'seeds.rb')
  end

  it 'creates prompts' do
    expect(Prompt.count).to be > 0
  end

  it 'creates prompts with a body' do
    expect(Prompt.first.body).not_to be_nil
  end

  it 'creates prompts with a body of type string' do
    expect(Prompt.first.body).to be_a(String)
  end
end
