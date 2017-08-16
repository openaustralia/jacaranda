# frozen_string_literal: true

require 'spec_helper'

describe 'validate_environment_varables!' do
  let(:envvars) { Jacaranda::Runner.required_environment_variables }
  subject { -> { Jacaranda::Runner.validate_environment_variables! } }

  context 'when all environment variables are set' do
    before(:each) { envvars.each { |var| set_environment_variable(var, Faker::Name.first_name) } }

    it 'does not exit' do
      is_expected.to_not raise_error
    end
  end

  context 'when any environment variables are not set' do
    before(:each) { envvars.each { |var| unset_environment_variable(var) } }

    it 'exits' do
      is_expected.to raise_error(SystemExit)
    end
  end

  after(:each) { restore_env }
end

describe 'Jacaranda#run' do
  let(:names) { Array.new(3) { Faker::Name.first_name } }
  let(:runners) do
    sorted = names.sort_by { |c| c.to_s.split('::').last }
    sorted.map { |name| Object.const_set(name, Class.new(Jacaranda::Runner)) }
  end

  it 'executes all runners by default' do
    expect(Jacaranda.runners.size).to be >= 2
  end

  it 'filters to a single runner' do
    args = %w[--runners] << runners.first.to_s
    Jacaranda.parse(args)
    expect(Jacaranda.runners.size).to be 1
    expect(Jacaranda.runners).to eq([runners.first])
  end

  it 'filters to multiple runners' do
    args = %w[--runners] << runners[0..1].join(',')
    Jacaranda.parse(args)
    expect(Jacaranda.runners.size).to be 2
    expect(Jacaranda.runners).to eq(runners[0..1])
  end
end

describe '#posted_in_last_fortnight?' do
  let(:text) { Faker::Lorem.paragraph(2) }

  context 'if record exists' do
    it do
      # Fake a successful post
      Jacaranda::Runner.record_successful_post(text)
      # Then test
      expect(Jacaranda::Runner.posted_in_last_fortnight?).to be true
    end
  end

  context 'if record does not exist' do
    it do
      expect(Jacaranda::Runner.posted_in_last_fortnight?).to be false
    end
  end

  context 'if posted > 14 days ago' do
    it nil, :aggregate_failures do
      10.times do
        # Fake a successful post
        text = Faker::RickAndMorty.quote
        Jacaranda::Runner.record_successful_post(text)
        # Test now
        expect(Jacaranda::Runner.posted_in_last_fortnight?).to be true
        # Test the future
        time_travel_to(Date.today + 15.days)
        expect(Jacaranda::Runner.posted_in_last_fortnight?).to be false
      end
    end
  end

  context 'when there is no schema or data' do
    it do
      expect(Jacaranda::Runner.posted_in_last_fortnight?).to be false
    end
  end
end

describe '#posts' do
  let(:names) { Array.new(3) { Faker::Name.first_name } }
  let(:runners) do
    sorted = names.sort_by { |c| c.to_s.split('::').last }
    sorted.map { |name| Object.const_set(name, Class.new(Jacaranda::Runner)) }
  end
  let(:count) { 10 }

  it 'only returns posts for the runner type', :aggregate_failures do
    runners.each do |runner|
      (1..count).each do |n|
        text = Faker::RickAndMorty.quote
        time_travel_to(n.days.ago) { runner.record_successful_post(text) }
      end
    end

    runners.each do |runner|
      expect(runner.posts.size).to eq(count)
    end
  end

  after(:each) { ScraperWiki.sqliteexecute('DELETE FROM data') }
end

describe '#run' do
  let(:url) { Faker::Internet.url('hooks.slack.com') }
  let(:text) { Faker::Lorem.paragraph(2) }

  before(:each) do
    set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
    set_environment_variable('MORPH_LIVE_MODE', 'true')
  end

  context 'posted in the last fortnight' do
    it 'does not run the scraper' do
      # Fake a successful post
      Jacaranda::Runner.record_successful_post(text)
      # Then run the runner
      expect(Jacaranda::Runner.run).to be false
    end
  end

  context 'not posted in the last fortnight' do
    it 'runs the scraper' do
      VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
        expect(Jacaranda::Runner.run).to be true
        expect(a_request(:post, url)).to have_been_made.times(1)
      end
    end
  end

  after(:each) do
    restore_env
    ScraperWiki.sqliteexecute('DELETE FROM data')
  end
end

describe '#post_to_slack' do
  let(:url) { Faker::Internet.url('hooks.slack.com') }
  let(:text) { Faker::Lorem.paragraph(2) }

  before(:each) { set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url) }

  context 'posting to Slack is successful' do
    it 'POSTs to webhook URL' do
      VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
        Jacaranda::Runner.post(text)
        expect(a_request(:post, url)).to have_been_made.times(1)
      end
    end

    it 'records the message' do
      VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
        Jacaranda::Runner.post(text)
        expect(Jacaranda::Runner.posted_in_last_fortnight?).to be true
      end
    end
  end

  context 'posting to Slack is not successful' do
    it 'does not record the message' do
      VCR.use_cassette('post_to_slack_webhook_but_fails', match_requests_on: [:host]) do
        Jacaranda::Runner.post(text)
        expect(Jacaranda::Runner.posted_in_last_fortnight?).to be false
      end
    end
  end

  after(:each) do
    restore_env
  end
end
