# frozen_string_literal: true

require "date"
require "uri"

class MeetupEvent
  DEFAULT_PHOTO = "https://tampa.dev/images/default.jpg"

  def self.photo_url(photo, w: 676, h: 380, fmt: "webp")
    return nil unless photo && photo[:baseUrl] && photo[:id]
    "#{photo[:baseUrl]}#{photo[:id]}/#{w}x#{h}.#{fmt}"
  end

  def self.format_slack(event)
    group_name = event.group&.dig(:name) || "Unknown Group"
    image_url = photo_url(event.photo) || DEFAULT_PHOTO

    event_blocks = [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*#{group_name}* - *#{event.title}*\n" \
                ":calendar: #{DateTime.parse(event.date_time).strftime('%A, %d %B %Y, %I:%M %p')}\n" \
                ":busts_in_silhouette: #{event.rsvp_count.to_i} going"
        },
        accessory: {
          type: "image",
          image_url: image_url,
          alt_text: "#{group_name} - #{event.title}"
        }
      },
      {
        type: "actions",
        elements: [
          {
            type: "button",
            text: {
              type: "plain_text",
              text: ":dart: RSVP",
              emoji: true
            },
            url: event.event_url
          }
        ]
      },
      { type: "divider" }
    ]

    if group_name == "Tampa Devs"
      event_blocks[0][:text][:text].prepend(":tampadevs: ")
    end

    if event.is_online
      event_blocks[0][:text][:text] += "\n\n:computer: Online event"
    elsif event.google_maps_url && event.address
      event_blocks[0][:text][:text] += "\n\n:round_pushpin: <#{event.google_maps_url}|#{event.address}>"
    end

    event_blocks
  end

  def self.link_utm(url, source: "", medium: "", campaign: "")
    uri = URI(url)
    params = URI.decode_www_form(uri.query || "")
    params << ["utm_source", source]
    params << ["utm_medium", medium]
    params << ["utm_campaign", campaign]
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
