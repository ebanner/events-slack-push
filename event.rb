# frozen_string_literal: true

require "date"
require "uri"

class MeetupEvent
  # Build a CDN photo URL from PhotoInfo or return nil
  def self.photo_url(photo, w: 676, h: 380, fmt: "webp")
    return nil unless photo && photo["baseUrl"] && photo["id"]
    "#{photo['baseUrl']}#{photo['id']}/#{w}x#{h}.#{fmt}"
  end

  # Prefer event photo; fallback to group photo (if caller passes it)
  def self.best_photo_url(event_node, group_hash, w: 676, h: 380)
    photo = event_node["featuredEventPhoto"] || group_hash["keyGroupPhoto"]
    photo_url(photo, w: w, h: h)
  end

  # Filter out noisy keys for venue display / maps
  def self.venue_parts(venue_hash)
    return [] unless venue_hash.is_a?(Hash)
    ignored = %w[lat lon latitude longitude]
    venue_hash.each_with_object([]) do |(k, v), parts|
      next if v.nil? || v == "" || ignored.include?(k)
      parts << v
    end
  end

  def self.parse_duration(iso8601_duration)
    match = (iso8601_duration || "PT0S").match(/PT((?<hours>\d+(?:\.\d+)?)H)?((?<minutes>\d+(?:\.\d+)?)M)?((?<seconds>\d+(?:\.\d+)?)S)?/)
    hours   = match && match[:hours]   ? match[:hours].to_i   : 0
    minutes = match && match[:minutes] ? match[:minutes].to_i : 0
    seconds = match && match[:seconds] ? match[:seconds].to_i : 0

    parts = []
    parts << "#{hours} hour#{"s" unless hours == 1}"   if hours > 0
    parts << "#{minutes} minute#{"s" unless minutes == 1}" if minutes > 0
    parts << "#{seconds} second#{"s" unless seconds == 1}" if seconds > 0
    (parts.empty? ? "0 minutes" : parts.join(", ")) + " long"
  end

  def self.within_next_two_weeks?(date_string)
    date = Date.parse(date_string)
    today = Date.today
    date >= today && date <= (today + 14)
  end

  def self.format_slack(group)
    return if group["events"]["totalCount"] == 0
    return unless within_next_two_weeks?(group["events"]["edges"][0]["node"]["dateTime"])

    event_node = group["events"]["edges"][0]["node"]

    # Fallback hierarchy for photo
    photo = event_node.dig("featuredEventPhoto") || group.dig("keyGroupPhoto")
    image_url = if photo
                  "#{photo['baseUrl']}#{photo['id']}/676x380.webp"
                else
                  "https://tampa.dev/images/default.jpg"
                end

    event_blocks = [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*#{group['name']}* - *#{event_node['title']}*\n" \
                ":calendar: #{DateTime.parse(event_node['dateTime']).strftime('%A, %d %B %Y, %I:%M %p')}\n" \
                ":busts_in_silhouette: #{event_node.dig('rsvps', 'totalCount') || 0} going"
        },
        accessory: {
          type: "image",
          image_url: image_url,
          alt_text: "#{group['name']} - #{event_node['title']}"
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
            url: event_node["eventUrl"]
          }
        ]
      },
      { type: "divider" }
    ]

    if group["name"] == "Tampa Devs"
      event_blocks[0][:text][:text].prepend(":tampadevs: ")
    end

    if event_node["venues"] && event_node["venues"].any?
      venue = event_node["venues"][0]
      if venue["name"] != "Online event"
        destination = venue.map { |k, v| "#{k}=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
        address = venue.values.reject { |v| v.is_a?(Numeric) }.join(", ")
        event_blocks[0][:text][:text] += "\n\n:round_pushpin: <https://www.google.com/maps/dir/?api=1&destination=#{destination}|#{address}>"
      else
        event_blocks[0][:text][:text] += "\n\n:computer: Online event"
      end
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