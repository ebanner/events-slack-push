# frozen_string_literal: true

require "date"
require "tampa_events_api"
require_relative "event"
require_relative "slack"

class EventSyndicator
  attr_accessor :dry_run, :formatted_events

  def initialize
    @dry_run = ENV["SYN_ENV"] != "production"
  end

  def fetch
    api = TampaEventsAPI::EventsApi.new
    events = api.call_20260125_events_next_get(within_days: "14", noempty: "1")

    # Sort events by date (earliest first)
    events.sort_by! { |e| DateTime.parse(e.date_time) }

    formatted_events = events.filter_map do |event|
      MeetupEvent.format_slack(event)
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
