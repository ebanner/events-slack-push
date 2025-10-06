# frozen_string_literal: true

require "json"
require "net/http"
require_relative "event"
require_relative "slack"

class EventSyndicator
  attr_accessor :dry_run, :formatted_events

  def initialize
    @dry_run = ENV["SYN_ENV"] != "production"
  end

  def fetch
    groups = JSON.parse(Net::HTTP.get(URI("https://events.api.tampa.dev/")))

    sorted_events = []
    formatted_events = []

    # groups is a Hash: { "GroupUrlname" => { ...group payload... }, ... }
    groups.values.each do |group|
      conn = group.dig("events")
      next unless conn && conn["totalCount"].to_i > 0 && conn["edges"].is_a?(Array) && !conn["edges"].empty?
      sorted_events << group
    end

    sorted_events.sort! do |a, b|
      a_dt = DateTime.parse(a["events"]["edges"][0]["node"]["dateTime"])
      b_dt = DateTime.parse(b["events"]["edges"][0]["node"]["dateTime"])
      a_dt <=> b_dt
    end

    sorted_events.each do |group|
      event = MeetupEvent.format_slack(group)
      formatted_events << event unless event.nil?
    end

    if formatted_events.empty?
      puts "No events to post, exiting with nothing to do."
      exit
    end

    Slack.syndicate(formatted_events, @dry_run)
  end
end

syn = EventSyndicator.new
syn.fetch