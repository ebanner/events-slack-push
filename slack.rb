# frozen_string_literal: true

require 'uri'
require 'net/https'
require 'json'

class Slack
  attr_accessor :keys, :message, :post_types, :utm_params

  def initialize
    @utm_params = {
      source: 'td_slack',
      medium: 'organic',
      campaign: 'tampadevs_meetup_promo'
    }

    @message = []
  end

  def self.syndicate(events, dry_run: true)
    return if events.empty?

    @payload = self.payload(events)

    self.post unless dry_run
    puts self.message_json if dry_run
  end

  def self.payload(events)
    header =  [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: ":balloon: Upcoming events for this week:"
          }
        },
        {
          type: "divider"
        }
      ]

    footer = [
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":earth_americas: See All Meetups",
              emoji: true
            },
            value: "see_all_meetups",
            url: "https://tampa.dev"
          }
        ]
      }
    ]

    [header, events.reduce([], :concat), footer].reduce([], :concat)
  end

  def self.message_json
    {
      blocks: @payload
    }.to_json
  end

  def self.post
    return if @payload.length == 0

    uri = URI.parse(ENV["TD_SLACK_WEBHOOK"])
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Accept'] = 'application/json'
    request.content_type = 'application/json'
    request.body = {
      blocks: @payload
    }.to_json

    https.request(request)
  end
end
