module PackReturnNavigation
  extend ActiveSupport::Concern

  private

  def valid_return_to?(url)
    url_from(url).present?
  end

  def append_new_pack_id(return_to_url, pack_id)
    uri = URI.parse(return_to_url)
    existing = URI.decode_www_form(uri.query || "")
    existing << [ "new_pack_id", pack_id.to_s ]
    uri.query = URI.encode_www_form(existing)
    uri.to_s
  rescue URI::InvalidURIError
    return_to_url
  end
end
