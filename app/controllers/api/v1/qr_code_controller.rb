# frozen_string_literal: true

# QR Code generation
module Api
  module V1
    class QrCodeController < ApplicationController
      require 'rqrcode'

      def site_qr_code
        ip_address = request.remote_ip
        port = Rails.application.config.action_controller.default_url_options[:port] || 3000
        qr_data = {
          ip_address: ip_address,
          port: port
        }
        qr = RQRCode::QRCode.new(qr_data.to_json)
        png = qr.as_png(
          bit_depth: 1,
          border_modules: 4,
          color_mode: ChunkyPNG::COLOR_GRAYSCALE,
          color: 'black',
          file: nil,
          fill: 'white',
          module_px_size: 6,
          resize_exactly_to: false,
          resize_gte_to: false,
          size: 480
        )
        send_data png.to_data_url, type: 'image/png', disposition: 'inline'
      end
    end
  end
end
