require "date"


def truncate_string(text, max_length = 1000)
  paragraphs = text.split("\n")

  paragraphs.each do |string|
    puts string
    puts
  end

  selected_paragraphs = []
  current_length = 0

  paragraphs.each do |paragraph|
    paragraph_length = paragraph.length + 2 # Adding 2 for the "\n\n" that will be re-inserted
    if current_length + paragraph_length > max_length
      selected_paragraphs << '...'
      break
    else
      selected_paragraphs << paragraph
      current_length += paragraph_length
    end
  end

  truncated_text = selected_paragraphs.join("\n")

  truncated_text.rstrip # Remove any trailing newlines
end


class MeetupEvent
  # Can be used like so:
  # \n:clock1: #{parse_duration(group['eventSearch']['edges'][0]['node']['duration'])
  def self.parse_duration(iso8601_duration)
    match = iso8601_duration.match(/PT((?<hours>\d+(?:\.\d+)?)H)?((?<minutes>\d+(?:\.\d+)?)M)?((?<seconds>\d+(?:\.\d+)?)S)?/)

    hours = match[:hours]&.to_i || 0
    minutes = match[:minutes]&.to_i || 0
    seconds = match[:seconds]&.to_i || 0

    parts = []
    parts << "#{hours} hour#{"s" unless hours == 1}" if hours > 0
    parts << "#{minutes} minute#{"s" unless minutes == 1}" if minutes > 0
    parts << "#{seconds} second#{"s" unless seconds == 1}" if seconds > 0

    parts.join(", ") + " long"
  end

  def self.within_next_two_weeks?(date_string)
    date = Date.parse(date_string)
    today = Date.today
    date >= today && date <= (today + 14)
  end

  def self.format_slack(group)
    return if group["eventSearch"]["count"] == 0

    return unless within_next_two_weeks?(group["eventSearch"]["edges"][0]["node"]["dateTime"])

    if group["eventSearch"]["edges"][0]["node"]["venue"]
      group["eventSearch"]["edges"][0]["node"]["location"] = if group["eventSearch"]["edges"][0]["node"]["venue"]["name"] != "Online event"
        ":round_pushpin: <https://www.google.com/maps/dir/?api=1&destination=#{group["eventSearch"]["edges"][0]["node"]["venue"].map { |k, v| "#{k}=#{URI.encode_www_form_component(v)}" }.join("&")}|#{group["eventSearch"]["edges"][0]["node"]["venue"].values.join(", ")}>"
      else
        ":computer: Online event"
      end
    end

    event_blocks = [
    {
      type: "section",
      text: {
        type: "mrkdwn",
        text: <<-HEREDOC
*#{group["name"]}* - *#{group["eventSearch"]["edges"][0]["node"]["title"]}*
:clock1: #{DateTime.parse(group["eventSearch"]["edges"][0]["node"]["dateTime"]).strftime("%I:%M %p")}
#{group["eventSearch"]["edges"][0]["node"]["location"]}
:busts_in_silhouette: #{group["eventSearch"]["edges"][0]["node"]["going"]} going
HEREDOC
      },
      accessory: {
        type: "image",
        image_url: group["eventSearch"]["edges"][0]["node"]["imageUrl"],
        alt_text: "#{group["name"]} - #{group["eventSearch"]["edges"][0]["node"]["title"]}"
      }
    },
    {
      type: "actions",
      elements: [
        {
          type: "button",
          text: {
            type: "plain_text",
            text: ":meetup: Event Details",
            emoji: true
          },
          url: group["eventSearch"]["edges"][0]["node"]["eventUrl"]
        }
      ]
    },
		{
			"type": "rich_text",
			"elements": [
				{
					"type": "rich_text_quote",
					"elements": [
						{
							"type": "text",
							"text": truncate_string(group["eventSearch"]["edges"][0]["node"]["description"]),
						}
					]
				}
			]
		}
    ]

    if group["name"] == "Tampa Devs"
      event_blocks[0][:text][:text].prepend(":tampadevs: ")
    end

    event_blocks
  end

  def self.link_utm(url, source: "", medium: "", campaign: "")
    uri = URI(url)

    params = URI.decode_www_form(uri.query || "") << ["utm_source", source]
    params << ["utm_medium", medium]
    params << ["utm_campaign", campaign]

    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
