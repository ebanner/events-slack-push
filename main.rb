# frozen_string_literal: true

require 'json'
require 'net/http'
require_relative 'event'
require_relative 'slack'

class EventSyndicator
  attr_accessor :dry_run, :formatted_events

  def initialize 
    @dry_run = ENV["SYN_ENV"] != "production"
  end


  def fetch
    groups = JSON.parse(Net::HTTP.get(URI('https://events.api.tampa.dev/')))

    formatted_events = []

    groups.each do |group|
      event = MeetupEvent.format_slack(group[1])
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
