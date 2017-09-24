# frozen_string_literal: true

require 'mechanize'

module RightToKnow
  # RightToKnow stats from righttoknow.org.au
  class Website
    class << self
      include Jacaranda::Runner::Posts
      def count(query, period:)
        start  = period.first.strftime('%D')
        finish = period.last.strftime('%D')
        base = "https://www.righttoknow.org.au/search/#{query}%20#{start}..#{finish}.html"
        agent = Mechanize.new
        # TODO: This iterates through pages looking for one with trustworthy
        #       results. It's guessing that the page number of the last page
        #       of results is no greater than 10. This is based on Right To Know's current usage,
        #       with a lot of padding built in. Currently the 3rd page is the last.
        #       Remove this logic and just get the results, once
        #       https://github.com/openaustralia/righttoknow/issues/673 is fixed.
        (1..10).to_a.reverse.each do |n|
          page = agent.get("#{base}?page=#{n}")
          return page.at('.foi_results').text.split.last if page.at('.foi_results')
        end
      end

      def new_requests_text(period:)
        [
          ':saxophone:',
          count('variety:sent', period: period),
          "new requests were made through Right To Know last #{frequency_adjective}."
        ].join(' ')
      end

      def annotations_text(period:)
        [
          ':heartbeat:',
          'Our contributors helped people with',
          count('variety:comment', period: period),
          'annotations.'
        ].join(' ')
      end

      def success_text(period:)
        [
          ':trophy:',
          count('status:successful', period: period),
          'requests were marked successful!'
        ].join(' ')
      end
    end
  end

  # The runner for RightToKnow
  class Runner < Jacaranda::BaseRunner
    default_post_day 'Wednesday'
    class << self
      def build
        [
          RightToKnow::Website.new_requests_text(period: last_period),
          RightToKnow::Website.annotations_text(period: last_period),
          RightToKnow::Website.success_text(period: last_period)
        ]
      end
    end
  end
end
