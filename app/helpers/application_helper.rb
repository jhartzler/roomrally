module ApplicationHelper
  def qr_code_svg(content, size: 250)
    require "rqrcode"
    qrcode = RQRCode::QRCode.new(content)
    svg = qrcode.as_svg(
      module_size: 6,
      standalone: true,
      use_path: true,
      viewbox: true
    )

    # Add explicit width and height attributes
    svg.sub("<svg", "<svg width='#{size}' height='#{size}'").html_safe
  end
end
