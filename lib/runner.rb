# frozen_string_literal: true

require 'scraperwiki'
require 'rest-client'
require 'optparse'

# Wrapper for all runners
module Jacaranda
  def self.run(args)
    parse(args)
    announce
    runners.each(&:run)
  end

  # rubocop:disable Metrics/MethodLength
  def self.parse(args)
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
      opts.on('-r', '--runners=RUNNER[,<RUNNER>,...]', 'Runners to execute') do |r|
        @whitelist = r.split(',')
      end
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end
    opt_parser.parse!(args)
  end
  # rubocop:enable Metrics/MethodLength

  def self.runners
    @whitelist ||= []
    candidates = self::Runner.descendants
    candidates.select! { |c| @whitelist.find { |w| c.to_s =~ /#{w}/i } } unless @whitelist.empty?
    candidates.sort_by { |c| c.to_s.split('::').last }
  end

  def self.announce
    puts 'These are the runners we will execute:'
    puts
    puts runners.map { |r| r.to_s.split('::').last }.join("\n")
    puts
    sleep(2)
  end

  # Boilerplate for running stat scrapers
  class Runner
    class << self
      def run
        validate_environment_variables!

        if posted_in_last_fortnight?
          puts "[#{name}] We have posted an update during this fortnight."
          false
        else
          puts "[#{name}] We have not posted an update during this fortnight."
          scrape_and_post_message
          true
        end
      end

      def required_environment_variables
        %w[MORPH_LIVE_MODE MORPH_SLACK_CHANNEL_WEBHOOK_URL]
      end

      def validate_environment_variables!
        return if required_environment_variables.all? { |var| ENV[var] }

        puts "[#{name}] The runner needs the following environment variables set:"
        puts
        puts required_environment_variables.join("\n")
        exit(1)
      end

      def posts
        query = "* from data where runner = '#{self}'"
        posts = ScraperWiki.select(query)
        posts.map do |post|
          post['date_posted'] = Date.parse(post['date_posted'])
          post
        end
      rescue
        []
      end

      def posted_in_last_fortnight?
        posts.any? { |post| post['date_posted'] > 1.fortnight.ago }
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
        opts = { url: ENV['MORPH_SLACK_CHANNEL_WEBHOOK_URL'] }
        opts[:channel] = '#bottesting' unless morph_live_mode?
        if post_message_to_slack(message, opts)
          puts "[#{name}] Recording the message in the database."
          record_successful_post(message)
        else
          puts "[#{name}] Error: could not post the message to Slack!"
        end
      end

      def record_successful_post(message)
        record = {
          date_posted: Date.today,
          text: message,
          runner: to_s
        }
        ScraperWiki.save_sqlite(%i[date_posted runner], record)
      end

      def print(message)
        puts
        puts message.gsub(/^/m, '> ')
        puts
      end

      def name
        to_s.split('::').last
      end
    end
  end
end
