# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'a runner' do
  let(:runner_name) { described_class.to_s.split('::').first.downcase }
  let(:url) { Faker::Internet.url('hooks.slack.com') }
  let(:cassette) { runner_name + '_post_to_slack_webhook' }

  before(:each) do
    set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
  end

  context 'on nominated day' do
    before(:each) do
      time_travel_to("next #{described_class.post_day}")
    end

    it 'runs' do
      VCR.use_cassette(cassette, match_requests_on: [:host]) do
        expect(described_class.run).to be true
        expect(a_request(:post, url)).to have_been_made.times(1)
      end
    end
  end

  context 'on days other than nominated day' do
    let(:days) { (1..6).map { |i| Date.parse(described_class.post_day) + i } }

    it 'does not run' do
      days.each do |day|
        time_travel_to(day)
        expect(described_class.run).to be false
        expect(a_request(:post, url)).to have_been_made.times(0)
      end
    end
  end
end
