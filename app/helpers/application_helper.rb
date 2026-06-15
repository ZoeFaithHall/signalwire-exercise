module ApplicationHelper
  # Hide the secret webhook token when showing a configured webhook URL.
  def masked_webhook_url(url)
    return url if url.blank?

    url.sub(/([?&]token=)[^&]+/, '\1••••••')
  end

  # Render a number's capabilities for display. The Relay REST search returns
  # them as an object ({"voice"=>true, "sms"=>false, ...}); tolerate a plain
  # array too in case the shape ever changes.
  def number_capabilities(capabilities)
    names =
      case capabilities
      when Hash  then capabilities.select { |_name, enabled| enabled }.keys
      when Array then capabilities
      else Array(capabilities)
      end
    names.join(", ")
  end
end
