# frozen_string_literal: true

# QR Code generation
module Api
  module V1
    class QrCodeController < ApplicationController
      require 'rqrcode'

      skip_before_action :authenticate
      skip_before_action :check_location

      def site_qr_code
        base64 = params[:base64]&.casecmp?('true')
        png = png_generator data: site_data
        if base64
          render json: { qr_code: "data:image/png;base64,#{Base64.encode64(png.to_s)}" }, status: :ok
        else
          send_data png.to_s, type: 'image/png', disposition: 'inline'
        end
      end

      private

      def encrypt_data(data)
        pass_key = YAML.load_file("#{Rails.root}/config/application.yml", aliases: true)[Rails.env]['qr_code_key']
        hashed_key = Digest::SHA256.digest(pass_key)
        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.encrypt # set the cipher to be encryption mode
        cipher.key = hashed_key # set the key
        encrypted = cipher.update(data) + cipher.final
        Base64.strict_encode64(encrypted)
      end

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
        qr = RQRCode::QRCode.new(encrypt_data(data.to_json))
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
