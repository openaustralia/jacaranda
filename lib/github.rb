# frozen_string_literal: true

require 'octokit'

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
