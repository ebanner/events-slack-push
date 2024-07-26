# frozen_string_literal: true

require "uri"
require "net/https"
require "json"

class Slack
  attr_accessor :keys, :message, :post_types, :utm_params

  def initialize
    @utm_params = {
      source: "td_slack",
      medium: "organic",
      campaign: "tampadevs_meetup_promo"
    }

    @message = []
  end

  def self.syndicate(events, dry_run)
    return if events.empty?

    @payload = payload(events)

    if dry_run
      puts message_json
    else
      post
    end
  end

  def self.payload(events)
    header = [
      # {
      #   type: "section",
      #   text: {
      #     type: "mrkdwn",
      #     text: "_:loudspeaker: 60 minutes until this event:_"
      #   }
      # },
      {
        "type": "header",
        "text": {
            "type": "plain_text",
            "text": ":loudspeaker: 60 minutes until this event"
        }
    },
    ]

    # puts events

    puts JSON.pretty_generate(events.reduce([], :concat))

    [header, events.reduce([], :concat)].reduce([], :concat)
  end

  def self.message_json
    {
      blocks: @payload
    }.to_json
  end

  def self.post
    return if @payload.length == 0

    targets = [ENV["TD_SLACK_WEBHOOK"]]

    targets.each do |t|
      uri = URI.parse(t)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Accept"] = "application/json"
      request.content_type = "application/json"
      request.body = {
        blocks: @payload
      }.to_json

      response = https.request(request)
      puts "#{response.code} #{response.message}: #{response.body}"
    end
  end
end
