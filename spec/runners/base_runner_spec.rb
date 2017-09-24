# frozen_string_literal: true

require 'spec_helper'

describe 'Jacaranda' do
  describe 'BaseRunner' do
    describe '#validate_environment_varables!' do
      let(:envvars) { Jacaranda::BaseRunner.required_environment_variables }
      subject { -> { Jacaranda::BaseRunner.validate_environment_variables! } }

      context 'when all environment variables are set' do
        before(:each) { envvars.each { |var| set_environment_variable(var, Faker::Name.first_name) } }

        it { is_expected.to_not raise_error }
      end

      context 'when any environment variables are not set' do
        before(:each) { envvars.each { |var| unset_environment_variable(var) } }

        it { is_expected.to raise_error(SystemExit) }
      end

      after(:each) { restore_env }
    end

    describe '#posted_in_last_period?' do
      subject { Jacaranda::BaseRunner }

      let(:runner_name) { subject.to_s.split('::').first.downcase }
      let(:runner_env_post_frequency) { "MORPH_RUNNERS_#{runner_name.upcase}_POST_FREQUENCY" }

      before(:each) do
        set_environment_variable(runner_env_post_frequency, frequency)
      end

      context 'weekly' do
        let(:duration) { 1.week }
        it_behaves_like 'a period'
      end

      context 'fortnightly' do
        let(:duration) { 2.weeks }
        it_behaves_like 'a period'
      end

      context 'monthly' do
        let(:duration) { 1.month }
        it_behaves_like 'a period'
      end

      context 'yearly' do
        let(:duration) { 1.year }
        it_behaves_like 'a period'
      end
    end

    describe '#posts' do
      it 'only returns posts for the runner type', :aggregate_failures do
        Jacaranda.runners.each do |runner|
          (1..10).each do |n|
            text = Faker::RickAndMorty.quote
            time_travel_to(n.days.ago) { runner.record_successful_post(text) }
          end
        end

        Jacaranda.runners.each do |runner|
          expect(runner.posts.size).to eq(10)
        end
      end

      after(:each) { ScraperWiki.sqliteexecute('DELETE FROM posts') }
    end

    describe '#run' do
      let(:url) { Faker::Internet.url('hooks.slack.com') }
      let(:text) { Faker::Lorem.paragraph(2) }

      before(:each) do
        set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
        set_environment_variable('MORPH_LIVE_MODE', 'true')
      end

      context 'posted in the last period' do
        it 'does not run the scraper' do
          # Fake a successful post
          Jacaranda::BaseRunner.record_successful_post(text)
          # Then run the runner
          expect(Jacaranda::BaseRunner.run).to be false
        end
      end

      context 'not posted in the last period' do
        before(:each) do
          time_travel_to("next #{Jacaranda::BaseRunner.post_day}")
        end

        it 'runs the scraper' do
          VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
            expect(Jacaranda::BaseRunner.run).to be true
            expect(a_request(:post, url)).to have_been_made.times(1)
          end
        end
      end

      context 'nominated day of the week' do
        before(:each) do
          time_travel_to("next #{Jacaranda::BaseRunner.post_day}")
        end

        it 'runs the scraper' do
          vcr_options = { match_requests_on: [:host], allow_playback_repeats: true }
          VCR.use_cassette('post_to_slack_webhook', vcr_options) do
            expect(Jacaranda::BaseRunner.run).to be true
            expect(a_request(:post, url)).to have_been_made.times(1)
          end
        end
      end

      context 'not nominated day of the week' do
        let(:days) { (1..6).map { |i| Date.parse(Jacaranda::BaseRunner.post_day) + i } }

        it 'does not run the scraper' do
          days.each do |day|
            time_travel_to(day)
            expect(Jacaranda::BaseRunner.run).to be false
            expect(a_request(:post, url)).to have_been_made.times(0)
          end
        end
      end

      after(:each) do
        restore_env
        query = %(SELECT sql FROM sqlite_master where name = 'posts' AND type = 'table')
        ScraperWiki.sqliteexecute('DELETE FROM posts') if ScraperWiki.sqliteexecute(query).any?
      end
    end

    describe '#post_to_slack' do
      let(:url) { Faker::Internet.url('hooks.slack.com') }
      let(:text) { Faker::Lorem.paragraph(2) }

      before(:each) { set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url) }

      context 'posting to Slack is successful' do
        it 'POSTs to webhook URL' do
          VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
            Jacaranda::BaseRunner.post(text)
            expect(a_request(:post, url)).to have_been_made.times(1)
          end
        end

        it 'records the message' do
          VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
            Jacaranda::BaseRunner.post(text)
            expect(Jacaranda::BaseRunner.posted_in_last_period?).to be true
          end
        end
      end

      context 'posting to Slack is not successful' do
        it 'does not record the message' do
          VCR.use_cassette('post_to_slack_webhook_but_fails', match_requests_on: [:host]) do
            Jacaranda::BaseRunner.post(text)
            expect(Jacaranda::BaseRunner.posted_in_last_period?).to be false
          end
        end
      end

      after(:each) do
        restore_env
      end
    end

    describe '#post_day' do
      subject { Jacaranda::BaseRunner }
      let(:runner_name) { subject.to_s.split('::').first.downcase }
      let(:runner_env_post_day) { "MORPH_RUNNERS_#{runner_name.upcase}_POST_DAY" }
      let(:days_of_week) { (0..6).map { |i| (Date.today + i).strftime('%A') } }

      it 'returns a default day' do
        expect(subject.post_day).to_not be nil
      end

      it 'is set by environment variables', :aggregate_failures do
        days_of_week.each do |day_name|
          set_environment_variable(runner_env_post_day, day_name)
          expect(subject.post_day).to eq(day_name)
        end
      end

      it 'validates the day set by environment variables', :aggregate_failures do
        days_of_week.each do |day_name|
          set_environment_variable(runner_env_post_day, "zzzz#{day_name}")
          expect { subject.post_day }.to raise_error(SystemExit)
        end
      end

      after(:each) { restore_env }
    end

    describe '#default_post_day' do
      context 'getter' do
        it 'defaults to Monday' do
          expect(Jacaranda::BaseRunner.default_post_day).to eq('Monday')
        end
      end

      context 'setter' do
        it 'converts to full day name' do
          Jacaranda::BaseRunner.default_post_day('sun')
          expect(Jacaranda::BaseRunner.default_post_day).to eq('Sunday')
        end

        it 'validates day name' do
          expect { Jacaranda::BaseRunner.default_post_day('zzz') }.to raise_error(SystemExit)
        end
      end
    end
  end
end
