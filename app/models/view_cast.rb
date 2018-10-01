# == Schema Information
#
# Table name: view_casts
#
#  id                               :integer          not null, primary key
#  datacast_identifier              :string(255)
#  template_card_id                 :integer
#  template_datum_id                :integer
#  name                             :string(255)
#  optionalconfigjson               :text
#  slug                             :string(255)
#  created_by                       :integer
#  updated_by                       :integer
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  seo_blockquote                   :text
#  status                           :text
#  folder_id                        :integer
#  is_invalidating                  :boolean
#  default_view                     :string(255)
#  by_line                          :string(255)
#  site_id                          :integer
#  is_open                          :boolean
#  is_autogenerated                 :boolean          default(FALSE)
#  is_disabled_for_edit             :boolean          default(FALSE)
#  byline_id                        :integer
#  ref_category_intersection_id     :integer
#  ref_category_sub_intersection_id :integer
#  ref_category_vertical_id         :integer
#  published_at                     :datetime
#  data_json                        :json
#  external_identifier              :string
#  format                           :string
#  importance                       :string           default("low")
#

class ViewCast < ApplicationRecord

    #CONSTANTS
    #CUSTOM TABLES
    #GEMS
    extend FriendlyId
    friendly_id :name, use: :slugged
    #CONCERNS
    include Propagatable
    include AssociableBySiFo
    #ASSOCIATIONS
    belongs_to :template_datum
    belongs_to :template_card
    has_many :permissions, ->{where(status: "Active", permissible_type: 'ViewCast')}, foreign_key: "permissible_id", dependent: :destroy
    has_many :users, through: :permissions
    belongs_to :series, class_name: "RefCategory", foreign_key: :ref_category_vertical_id, optional: true
    belongs_to :intersection, class_name: "RefCategory", foreign_key: :ref_category_intersection_id, optional: true
    belongs_to :sub_intersection, class_name: "RefCategory", foreign_key: :ref_category_sub_intersection_id, optional: true

    #ACCESSORS
    attr_accessor :dataJSON, :schemaJSON, :stop_callback, :redirect_url, :collaborator_lists

    #VALIDATIONS
    validates :slug, uniqueness: true

    #CALLBACKS
    before_create :before_create_set
    after_save :after_save_set
    after_create :after_create_set
    before_save :before_save_set
    after_commit :after_commit_set
    before_destroy :before_destroy_set

    #SCOPE
    default_scope ->{includes(:site)} # remove/replace with site

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
        "#{self.site.cdn_endpoint}/#{self.datacast_identifier}/data.json"
    end

    def cdn_url
        "#{self.site.cdn_endpoint}/#{self.datacast_identifier}/view_cast.json"
    end

    def should_generate_new_friendly_id?
        name_changed?
    end

    def page
        if self.is_autogenerated
            Page.where(view_cast_id: self.id).first
        else
            Page.none
        end
    end

    def self.order_by_ids(ids)
        order_by = ["CASE"]
        ids.each_with_index do |id, index|
            order_by << "WHEN id='#{id}' THEN #{index}"
        end
        order_by << "END"
        order(order_by.join(" "))
    end

    #PRIVATE
    private

    def before_create_set
        self.optionalconfigjson = {} if self.optionalconfigjson.blank?
        self.default_view = self.template_card.allowed_views.first if self.default_view.blank?
    end

    def before_save_set
        self.datacast_identifier = SecureRandom.hex(12) if self.datacast_identifier.blank?
        if self.folder.present? and self.series.blank? and self.folder.vertical.present?
            self.series = self.folder.vertical
        end
        unless self.optionalconfigjson.nil?
            key = "#{self.datacast_identifier}/view_cast.json"
            encoded_file = Base64.encode64(self.optionalconfigjson)
            content_type = "application/json"
            resp = Api::ProtoGraph::Utility.upload_to_cdn(encoded_file, key, content_type, self.site.cdn_bucket)
        end
        self.seo_blockquote = self.seo_blockquote.to_s.gsub('\\', '\\\\')
        # self.seo_blockquote = self.seo_blockquote.to_s.split('`').join('\`') #.gsub('`', '\`')
        self.seo_blockquote = self.seo_blockquote.to_s.gsub('${', '\${')
    end

    def after_save_set
        if self.collaborator_lists.present?
            self.collaborator_lists = self.collaborator_lists.reject(&:empty?)
            prev_collaborator_ids = self.permissions.pluck(:user_id)
            self.collaborator_lists.each do |c|
                user = User.find(c)
                a = user.create_permission("ViewCast", self.id, "contributor")
            end
            self.permissions.where(permissible_id: (prev_collaborator_ids - self.collaborator_lists.map{|a| a.to_i})).update_all(status: 'Deactivated')
        end
        #self.update_column(:published_at, self.updated_at) if ["toStory", "toCluster"].exclude?(self.template_card.name)
    end

    def after_commit_set
        StreamUpdateWorker.perform_async(self.id) if Rails.env.production?
    end

    def after_create_set
        #Update Template Card and Template Datum
    end

    def before_destroy_set
        payload = {}
        payload['folder_name'] = self.datacast_identifier
        payload["bucket_name"] = site.cdn_bucket
        begin
            Api::ProtoGraph::Datacast.delete(payload)
        rescue => e
        end
    end
end
