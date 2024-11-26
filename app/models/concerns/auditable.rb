# frozen_string_literal: true

# Gives ActiveRecord models an auditable behaviour
#
# Models with the Auditable behaviour automagically get their
# date_changed and changed_by field set to the currently logged
# in user.
#
# USAGE:
#  class ApplicationRecord < ActiveRecord::Model
#    include Auditable
#    ...
#  end
module Auditable
  extend ActiveSupport::Concern

  included do
    before_save :update_change_trail
    before_create :update_create_trail
    before_create :auto_increment_composite_key
  end

  # Saves current user after every save
  def update_change_trail
    unless respond_to?(:changed_by) && respond_to?(:date_changed)
      Rails.logger.warn "Auditable model missing changed_by or date_changed: #{self}"
      return
    end

    self.changed_by ||= User.current&.user_id
    Rails.logger.warn 'Auditable::update_change_trail called outside login' unless changed_by

    self.date_changed = Time.now
  end

  def update_create_trail
    unless respond_to?(:date_created) && respond_to?(:creator)
      Rails.logger.warn "Auditable model missing creator or date_created: #{self}"
      return
    end

    self.creator = User.current.user_id if creator.nil? || creator.zero?
    Rails.logger.warn 'Auditable::update_create_trail called outside login' unless creator

    self.date_created = Time.now
  end

  def composite_key?
    self.class.composite? && (self.class.primary_key.is_a?(Array) && self.class.primary_key.length == 2)
  end

  def composite_key_has_site_id?
    self.class.primary_key.include?('site_id')
  end

  # rubocop:disable Metrics/AbcSize
  def auto_increment_composite_key
    return unless composite_key? && composite_key_has_site_id?

    composite_key_column = (self.class.primary_key - ['site_id']).first
    unless composite_key_column && respond_to?(:site_id) && respond_to?(composite_key_column.to_sym)
      Rails.logger.warn "Auditable model missing site_id or #{composite_key_column}: #{self}"
      return
    end

    last_value = self.class.where(site_id:).maximum(composite_key_column.to_sym) || 0
    self[composite_key_column] = last_value + 1
  end
  # rubocop:enable Metrics/AbcSize

  def auditable?
    respond_to?(:changed_by) && respond_to?(:date_changed)
  end
end
