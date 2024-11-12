# frozen_string_literal: true

# QR Code generation
module Api
  module V1
    class QrCodeController < ApplicationController
      require 'rqrcode'

      skip_before_action :authenticate
      skip_before_action :check_location

      def site_qr_code
        png = png_generator data: site_data
        send_data png.to_s, type: 'image/png', disposition: 'inline'
      end

      private

      ## The code should be moved to a service if the needs start to grow extremely
      def site_data
        qr_data = {
          ip_address: request.remote_ip,
          port: request.port || 3000,
          site_name: GlobalProperty.find_by(property: 'current_health_center_name')&.property_value,
          site_code: GlobalProperty.find_by(property: 'site_prefix')&.property_value
        }
      end


      def png_generator(data:)
        qr = RQRCode::QRCode.new(data.to_json)
        qr.as_png(
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
      end
    end
  end
end
