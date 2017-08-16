# frozen_string_literal: true

require 'dotenv'
Dotenv.load
require_relative 'lib/github'
require_relative 'lib/planningalerts'
require_relative 'lib/righttoknow'
require_relative 'lib/runner'

module Jacaranda
  # The runner for PlanningAlerts
  class PlanningAlerts < Runner
    class << self
      def build
        [
          ::PlanningAlerts.new_subscribers_text(period: last_fortnight),
          ::PlanningAlerts.new_unsubscribers_text(period: last_fortnight),
          ::GitHub.commits_text(period: last_fortnight),
          ::PlanningAlerts.total_subscribers_text
        ]
      end
    end
  end

  # The runner for RightToKnow
  class RightToKnow < Runner
    class << self
      def build
        [
          ::RightToKnow.new_requests_text(period: last_fortnight),
          ::RightToKnow.annotations_text(period: last_fortnight),
          ::RightToKnow.success_text(period: last_fortnight)
        ]
      end
    end
  end
end

Jacaranda.run(ARGV) if $PROGRAM_NAME == __FILE__
