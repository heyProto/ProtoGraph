# == Schema Information
#
# Table name: view_casts
#
#  id                  :integer          not null, primary key
#  account_id          :integer
#  datacast_identifier :string(255)
#  template_card_id    :integer
#  template_datum_id   :integer
#  name                :string(255)
#  optionalConfigJSON  :text(65535)
#  slug                :string(255)
#  created_by          :integer
#  updated_by          :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  seo_blockquote      :text(65535)
#  status              :text(65535)
#  folder_id           :integer
#  is_invalidating     :boolean
#  default_view        :string(255)
#  genre               :string(255)
#  sub_genre           :string(255)
#  series              :string(255)
#  by_line             :string(255)
#  site_id             :integer
#  is_open             :boolean
#

class ViewCast < ApplicationRecord
    #CONSTANTS
    Datacast_ENDPOINT = "#{ENV['AWS_S3_ENDPOINT']}"
    #CUSTOM TABLES

    #GEMS
    extend FriendlyId
    friendly_id :name, use: :slugged
    #ASSOCIATIONS
    belongs_to :account
    belongs_to :folder
    belongs_to :template_datum
    belongs_to :template_card
    belongs_to :site
    belongs_to :creator, class_name: "User", foreign_key: "created_by"
    belongs_to :updator, class_name: "User", foreign_key: "updated_by"
    has_many :permissions, ->{where(status: "Active", permissible_type: 'ViewCast')}, foreign_key: "permissible_id", dependent: :destroy
    has_many :users, through: :permissions
    #ACCESSORS
    attr_accessor :dataJSON, :schemaJSON, :stop_callback, :redirect_url, :collaborator_lists
    #VALIDATIONS
    validates :slug, uniqueness: true
    validates :folder_id, presence: true
    #CALLBACKS
    before_create :before_create_set
    after_create :after_create_set
    before_save :before_save_set
    after_save :after_save_set
    before_destroy :before_destroy_set
    #SCOPE
    default_scope ->{includes(:account)}
    #OTHER

    def remote_urls
        {
            "data_url": self.data_url,
            "configuration_url": self.cdn_url,
            "schema_json": self.schema_json,
            "base_url": self.template_card.base_url
        }
    end

    def schema_json
        "#{self.template_datum.schema_json}"
    end

    def data_url
        "#{Datacast_ENDPOINT}/#{self.datacast_identifier}/data.json"
    end

    def cdn_url
        "#{Datacast_ENDPOINT}/#{self.datacast_identifier}/view_cast.json"
    end

    def should_generate_new_friendly_id?
        name_changed?
    end

    #PRIVATE
    private

    def before_create_set
        self.optionalConfigJSON = {} if self.optionalConfigJSON.blank?
        self.default_view = self.template_card.allowed_views.first if self.default_view.blank?
    end

    def before_save_set
        self.datacast_identifier = SecureRandom.hex(12) if self.datacast_identifier.blank?
        if self.optionalConfigJSON_changed? and self.optionalConfigJSON.present?
            key = "#{self.datacast_identifier}/view_cast.json"
            encoded_file = Base64.encode64(self.optionalConfigJSON)
            content_type = "application/json"
            resp = Api::ProtoGraph::Utility.upload_to_cdn(encoded_file, key, content_type)
        end
        self.seo_blockquote = self.seo_blockquote.to_s.gsub('\\', '\\\\')
        # self.seo_blockquote = self.seo_blockquote.to_s.split('`').join('\`') #.gsub('`', '\`')
        self.seo_blockquote = self.seo_blockquote.to_s.gsub('${', '\${')
    end

    def after_save_set
        # Update the streams
        # StreamUpdateWorker.perform_async(self.id)
        if self.collaborator_lists.present?
            self.collaborator_lists = self.collaborator_lists.reject(&:empty?)
            prev_collaborator_ids = self.permissions.pluck(:user_id)
            self.collaborator_lists.each do |c|
                user = User.find(c)
                a = user.create_permission("ViewCast", self.id, "contributor")
            end
            self.permissions.where(permissible_id: (prev_collaborator_ids - self.collaborator_lists.map{|a| a.to_i})).update_all(status: 'Deactivated')
        end
    end

    def after_create_set
        template_card = self.template_card
        template_card.update_attributes(publish_count: (template_card.publish_count.to_i + 1))
        template_datum = self.template_datum
        template_datum.update_attributes(publish_count: (template_datum.publish_count.to_i + 1))
    end

    def before_destroy_set
        payload = {}
        payload['folder_name'] = self.datacast_identifier
        begin
            Api::ProtoGraph::Datacast.delete(payload)
        rescue => e
        end
        self.template_card.update_column(:publish_count, (self.template_card.publish_count.to_i - 1))
    end
end
