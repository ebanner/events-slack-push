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
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: ":balloon: Upcoming events:"
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
              text: ":earth_americas: All Meetups",
              emoji: true
            },
            value: "see_all_meetups",
            url: "https://tampa.dev?utm_source=td_slack_syndication&utm_campaign=organic"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":calendar: Event Calendar",
              emoji: true
            },
            value: "newsletter_tampa_dev",
            url: "https://go.tampa.dev/calendar?utm_source=td_slack_syndication&utm_campaign=organic"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":zap: Events API",
              emoji: true
            },
            value: "events_api",
            url: "https://github.com/TampaDevs/events.api.tampa.dev"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":briefcase: Local Tech Jobs",
              emoji: true
            },
            value: "events_api",
            url: "https://talent.tampa.dev?utm_source=td_slack_syndication&utm_campaign=organic"
          },
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":newspaper: Newsletter",
              emoji: true
            },
            value: "newsletter_tampa_dev",
            url: "https://newsletter.tampa.dev?utm_source=td_slack_syndication&utm_campaign=organic"
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

    targets = [ENV["TD_SLACK_WEBHOOK"], ENV["TBT_SLACK_WEBHOOK"], ENV["TBUX_SLACK_WEBHOOK"]]

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
