# frozen_string_literal: true

require 'mechanize'
require 'rest-client'
require 'json'
require 'active_support/all'
require 'octokit'

# Duck punches
class Numeric
  def percent_of(n)
    to_f / n.to_f * 100.0
  end
end

module PlanningAlerts
  # PlanningAlerts stats from planningalerts.org.au
  class Website
    class << self
      def new_subscribers_text(period:)
        before_period = determine_period_before(period)

        puts 'Collect new subscriber information from PlanningAlerts'
        period_count        = count('new_alert_subscribers', period: period)
        period_before_count = count('new_alert_subscribers', period: before_period)

        [
          period_count,
          'people signed up for PlanningAlerts last fortnight :revolving_hearts:',
          change_sentence(period_count, period_before_count)
        ].join(' ')
      end

      def new_unsubscribers_text(period:)
        before_period = determine_period_before(period)

        puts 'Collect new unsubscriber information from PlanningAlerts'
        period_count        = count('emails_completely_unsubscribed', period: period)
        period_before_count = count('emails_completely_unsubscribed', period: before_period)

        [
          period_count,
          'people left.',
          change_sentence(period_count, period_before_count)
        ].join(' ')
      end

      def total_subscribers_text
        puts 'Collect total subscribers information from PlanningAlerts'
        number = total_planningalerts_subscribers.round(-2)
        format = { precision: 0, delimiter: ',' }
        [
          'There are now',
          ActiveSupport::NumberHelper.number_to_rounded(number, format),
          'PlanningAlerts subscribers! :star2:'
        ].join(' ')
      end

      private

      def determine_period_before(period)
        (period.first.advance(weeks: -2)..period.last.advance(weeks: -2)).to_a
      end

      def total_planningalerts_subscribers
        # Memoize if we have fetched the data before
        return @subscribers_count if @subscribers_count
        # Otherwise pull the data from the PlanningAlerts website
        page = Mechanize.new.get('https://www.planningalerts.org.au/performance')
        @subscribers_count = page.at('#content h2').text.split(' ').first.to_i
      end

      def percentage_change_in_words(change)
        [
          change.to_s.delete('-') + '%',
          (change.positive? ? 'more' : 'less')
        ].join(' ')
      end

      def change_sentence(last_fortnight, fortnight_before_last)
        percentage_change_from_fortnight_before = last_fortnight.percent_of(fortnight_before_last) - 100
        percentage_change_from_fortnight_before = 0 if percentage_change_from_fortnight_before.nan?
        percentage_change_from_fortnight_before = percentage_change_from_fortnight_before.round(1).floor

        [
          'That’s',
          percentage_change_in_words(percentage_change_from_fortnight_before),
          'than the fortnight before.'
        ].join(' ')
      end

      def subscribers_data
        # Memoize if we have fetched the data before
        return @subscribers_data if @subscribers_data
        # Otherwise fetch the data, with a _long_ timeout.
        url = 'https://www.planningalerts.org.au/performance/alerts.json'
        response = RestClient::Request.execute(method: :get, url: url, timeout: 300)
        @subscribers_data = JSON.parse(response)
      end

      def count(attribute, period:)
        count = 0

        period.each do |date|
          subscribers_data.each do |row|
            count += row[attribute] if row['date'] == date.to_s
          end
        end

        count
      end
    end
  end

  # PlanningAlerts contributor stats from GitHub
  class GitHub
    class << self
      def commits_text(period:)
        puts 'Collect information from GitHub'
        if commits_count(period: period).zero?
          nil
        else
          "You shipped #{commits_count(period: period)} commits in the same period."
        end
      end

      private

      def commits_count(period:)
        github = Octokit::Client.new
        github.auto_paginate = true
        repo = 'openaustralia/planningalerts'
        params = { since: period.first, until: period.last }
        commits = github.commits(repo, params)
        commits.size
      end
    end
  end

  # The runner for PlanningAlerts
  class Runner < Jacaranda::BaseRunner
    default_post_day 'Monday'
    class << self
      def build
        [
          PlanningAlerts::Website.new_subscribers_text(period: last_fortnight),
          PlanningAlerts::Website.new_unsubscribers_text(period: last_fortnight),
          PlanningAlerts::GitHub.commits_text(period: last_fortnight),
          PlanningAlerts::Website.total_subscribers_text
        ]
      end
    end
  end
end
