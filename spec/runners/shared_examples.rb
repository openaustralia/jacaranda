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

RSpec.shared_examples 'a period' do
  let(:text) { Faker::Lorem.paragraph(2) }
  let(:frequency) { self.class.parent.parent.description }

  context 'if record exists' do
    it do
      # Fake a successful post
      Jacaranda::BaseRunner.record_successful_post(text)
      # Then test
      expect(Jacaranda::BaseRunner.posted_in_last_period?).to be true
    end
  end

  context 'if record does not exist' do
    it { expect(Jacaranda::BaseRunner.posted_in_last_period?).to be false }
  end

  context 'if posted outside period' do
    it nil, :aggregate_failures do
      10.times do
        # Fake a successful post
        text = Faker::RickAndMorty.quote
        Jacaranda::BaseRunner.record_successful_post(text)
        # Test now
        expect(Jacaranda::BaseRunner.posted_in_last_period?).to be true
        # Test the future
        time_travel_to(Date.today + duration + 1.day)
        expect(Jacaranda::BaseRunner.posted_in_last_period?).to be false
      end
    end
  end

  context 'when there is no schema or data' do
    it do
      expect(Jacaranda::BaseRunner.posted_in_last_period?).to be false
    end
  end
end
