# frozen_string_literal: true
require 'date'

class MeetupEvent
    
  # Can be used like so:
  # \n:clock1: #{parse_duration(group['eventSearch']['edges'][0]['node']['duration'])
  def self.parse_duration(iso8601_duration)
    match = iso8601_duration.match(/PT((?<hours>\d+(?:\.\d+)?)H)?((?<minutes>\d+(?:\.\d+)?)M)?((?<seconds>\d+(?:\.\d+)?)S)?/)
    
    hours = match[:hours]&.to_i || 0
    minutes = match[:minutes]&.to_i || 0
    seconds = match[:seconds]&.to_i || 0
  
    parts = []
    parts << "#{hours} hour#{'s' unless hours == 1}" if hours > 0
    parts << "#{minutes} minute#{'s' unless minutes == 1}" if minutes > 0
    parts << "#{seconds} second#{'s' unless seconds == 1}" if seconds > 0
  
    parts.join(', ') + " long"
  end

  def self.within_next_seven_days?(date_string)
    date = Date.parse(date_string)
    today = Date.today
    date >= today && date <= (today + 7)
  end

  def self.format_slack(group)
    return if group['eventSearch']['count'] == 0

    return unless within_next_seven_days?(group['eventSearch']['edges'][0]['node']['dateTime'])

		event_blocks = [{
			type: "section",
			text: {
				type: "mrkdwn",
				text: "*#{group['name']}* - *#{group['eventSearch']['edges'][0]['node']['title']}*\n:calendar: #{DateTime.parse(group['eventSearch']['edges'][0]['node']['dateTime']).strftime("%A, %d %B %Y, %I:%M %p")}\n:busts_in_silhouette: #{group['eventSearch']['edges'][0]['node']['going']} going"
			},
			accessory: {
				type: "image",
				image_url: group['eventSearch']['edges'][0]['node']['imageUrl'],
				alt_text: "#{group['name']} - #{group['eventSearch']['edges'][0]['node']['title']}"
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
					url: group['eventSearch']['edges'][0]['node']['eventUrl']
				},
				{
					type: "button",
					text: {
						type: "plain_text",
						text: ":dizzy: All Events",
						emoji: true
					},
					url: group['link']
				}
			]
		},
		{
			type: "divider"
		}]

	if group['name'] == 'Tampa Devs'
		event_blocks[0][:text][:text].prepend(":tampadevs: ")
	end

    if group['eventSearch']['edges'][0]['node']['venue']
      if group['eventSearch']['edges'][0]['node']['venue']['name'] != 'Online event'
        event_blocks[0][:text][:text] += "\n\n:round_pushpin: <https://www.google.com/maps/dir/?api=1&destination=#{group['eventSearch']['edges'][0]['node']['venue'].map {|k, v| "#{k}=#{URI.encode_www_form_component(v)}"}.join('&')}|#{group['eventSearch']['edges'][0]['node']['venue'].values.join(', ')}>"
      else
        event_blocks[0][:text][:text] += "\n\n:computer: Online event"
      end
    end 

    event_blocks
  end 
  
  def self.link_utm(url, source: '', medium: '', campaign: '')
    uri = URI(url)
    
    params = URI.decode_www_form(uri.query || "") << ["utm_source", source]
    params << ["utm_medium", medium]
    params << ["utm_campaign", campaign]

    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
