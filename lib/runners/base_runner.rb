# frozen_string_literal: true

require 'scraperwiki'
require 'rest-client'

module Jacaranda
  module Runner
    # Common validations for all Jacaranda runners
    module Validations
      def required_environment_variables
        [
          'MORPH_LIVE_MODE',
          "MORPH_RUNNERS_#{name.upcase}_WEBHOOK_URL"
        ]
      end

      def validate_environment_variables!
        return if required_environment_variables.all? { |var| ENV[var] }

        puts "[#{name}] The runner needs the following environment variables set:"
        puts
        puts required_environment_variables.join("\n")
        exit(1)
      end

      def validated_date!(value)
        Date.parse(value).strftime('%A')
      rescue ArgumentError => e
        puts "[#{name}] #{e.message}. Exiting!"
        exit(1)
      end
    end

    # Methods for interacting with Slack
    module Slack
      def post_message_to_slack(text, opts = {})
        options = { username: 'Jacaranda', text: text }.merge(opts)
        url = options.delete(:url)
        raise ArgumentError, 'Must supply :url in options' unless url

        begin
          RestClient.post(url, options.to_json) =~ /ok/i
        rescue RestClient::Exception
          false
        end
      end

      def slack_channel
        ENV["MORPH_RUNNERS_#{name.upcase}_WEBHOOK_CHANNEL"]
      end
    end

    # Methods for post CRUD
    module Posts
      def posts
        posts = ScraperWiki.select("* from posts where runner = '#{self}'")
        normalise_dates(posts)
      rescue
        []
      end

      def normalise_dates(posts)
        posts.map do |post|
          post['date_posted'] = Date.parse(post['date_posted'])
          post
        end
      end

      def posted_in_last_fortnight?
        posts.any? { |post| post['date_posted'] > 1.fortnight.ago }
      end

      def record_successful_post(message)
        record = {
          date_posted: Date.today,
          text: message,
          runner: to_s
        }
        ScraperWiki.save_sqlite(%i[date_posted runner], record, 'posts')
      end
    end

    # Methods for runner scheduling
    module Schedule
      def post_day?
        if Date.today.strftime('%A').casecmp(post_day).zero?
          true
        else
          puts "[#{name}] Skipping because it's not #{post_day}"
          false
        end
      end

      def default_post_day(*args)
        if args.first
          @default_post_day = validated_date!(args.first)
        else
          @default_post_day || 'Monday'
        end
      end

      def post_day
        post_day_from_env || default_post_day
      end

      def post_day_from_env
        value = ENV["MORPH_RUNNERS_#{name.upcase}_POST_DAY"]
        return value unless value
        validated_date!(value)
      end
    end
  end

  # Boilerplate for running stat scrapers
  class BaseRunner
    class << self
      include Runner::Validations
      include Runner::Posts
      include Runner::Schedule
      include Runner::Slack

      def run
        validate_environment_variables!
        return false unless post_day?

        if posted_in_last_fortnight?
          puts "[#{name}] We have posted an update during this fortnight."
          false
        else
          puts "[#{name}] We have not posted an update during this fortnight."
          scrape_and_post_message
          true
        end
      end

      def morph_live_mode?
        ENV['MORPH_LIVE_MODE'] == 'true'
      end

      def scrape_and_post_message
        message = build.compact.join("\n\n")

        if morph_live_mode?
          puts "[#{name}] Posting the message to Slack."
          post(message)
        else
          puts "[#{name}] Not posting to Slack."
          puts "[#{name}] Not recording the message in the database."
          print(message)
        end
      end

      def last_fortnight
        start  = 1.fortnight.ago.beginning_of_week.to_date
        finish = 1.week.ago.end_of_week.to_date
        (start..finish).to_a
      end

      def build
        [
          'This is a stub runner.',
          "You should inherit #{self} and override."
        ]
      end

      def post(message)
        opts = { url: ENV["MORPH_RUNNERS_#{name.upcase}_WEBHOOK_URL"] }
        opts[:channel] = slack_channel if slack_channel
        if post_message_to_slack(message, opts)
          puts "[#{name}] Recording the message in the database."
          record_successful_post(message)
        else
          puts "[#{name}] Error: could not post the message to Slack!"
        end
      end

      def print(message)
        puts
        puts message.gsub(/^/m, '> ')
        puts
      end

      def name
        to_s.split('::').first
      end
    end
  end
end
