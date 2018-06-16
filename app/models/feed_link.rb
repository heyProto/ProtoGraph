# == Schema Information
#
# Table name: feed_links
#
#  id              :integer          not null, primary key
#  ref_category_id :integer
#  feed_id         :integer
#  view_cast_id    :integer
#  link            :text
#  headline        :text
#  published_at    :datetime
#  description     :text
#  cover_image     :text
#  author          :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class FeedLink < ApplicationRecord

  #CONSTANTS
  #CUSTOM TABLES
  #GEMS
  #CONCERNS
  #ASSOCIATIONS
  belongs_to :ref_category
  belongs_to :feed
  has_one :view_cast, class_name: "ViewCast", foreign_key: "id", primary_key: "view_cast_id" #, dependent: :destroy

  #ACCESSORS
  attr_accessor :temp_headline
  #VALIDATIONS
  validates :link, presence: true, format: {:with => /[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}/ }
  validates :ref_category_id, presence: true
  validates :feed_id, presence: true

  #CALLBACKS
  #SCOPE
  #OTHER
  def create_or_update_view_cast
    ref_category = self.ref_category
    feed = self.feed
    payload_json = create_datacast_json
    if self.view_cast.present?
      view_cast = self.view_cast
      view_cast.update({
        name: self.temp_headline || self.headline,
        seo_blockquote: TemplateCard.to_cluster_render_SEO(payload_json["data"]),
        folder_id: ref_category.folder.present? ? ref_category.folder.id : nil,
        is_autogenerated: true,
        optionalconfigjson: {},
        updated_by: feed.updated_by,
        published_at: self.published_at
      })
    else
      view_cast = ViewCast.create({
        name: self.temp_headline || self.headline,
        site_id: ref_category.site.id,
        template_card_id: TemplateCard.where(name: 'toCluster').first.id,
        template_datum_id: TemplateDatum.where(name: 'toCluster').first.id,
        seo_blockquote: TemplateCard.to_cluster_render_SEO(payload_json["data"]),
        folder_id: ref_category.folder.present? ? ref_category.folder.id : nil,
        default_view: "title_text",
        account_id: ref_category.site.account.id,
        created_by: feed.created_by,
        updated_by: feed.updated_by,
        is_autogenerated: true,
        optionalconfigjson: {},
        published_at: self.published_at
      })
    end
    payload = {}
    payload["payload"] = payload_json.to_json
    payload["api_slug"] = view_cast.datacast_identifier
    payload["schema_url"] = view_cast.template_datum.schema_json
    payload["source"] = "form"
    payload["bucket_name"] = ref_category.site.cdn_bucket
    if self.view_cast.present?
      r = Api::ProtoGraph::Datacast.update(payload)
    else
      r = Api::ProtoGraph::Datacast.create(payload)
      self.update_column(:view_cast_id, view_cast.id)
      add_card_to_stream
    end
    Api::ProtoGraph::CloudFront.invalidate(self.ref_category.site, ["/#{view_cast.datacast_identifier}/*"], 1)
  end

  def create_datacast_json
    require 'uri'
    data = {"data" => {}}
    data["data"]["section"] = self.temp_headline || self.headline
    data["data"]["title"] = self.temp_headline || self.headline
    data["data"]["published_date"] = self.published_at.utc
    data["data"]["links"] = []
    data["data"]["links"][0] = {}
    data["data"]["links"][0]["link"] = self.link if self.link.present?

    parsed_link = URI.parse(self.link)
    link = "#{parsed_link.scheme}://#{parsed_link.host}"
    ref_link_source = RefLinkSource.where(url: link).first
    if ref_link_source.present?
      data["data"]["links"][0]["favicon_url"] = ref_link_source.favicon_url
      data["data"]["links"][0]["publication_name"] = ref_link_source.favicon_url
    else
      data["data"]["links"][0]["favicon_url"] = "https://cdn.protograph.pykih.com/lib/toCluster_default_favicon.png"
      data["data"]["links"][0]["publication_name"] = parsed_link.host
    end
    data
  end

  def add_card_to_stream
    page = self.ref_category.vertical_page #self.ref_category.pages.where(template_page_id: TemplatePage.find_by(name: "Homepage: Vertical").id).first
    if page.present?
      feed_stream = page.streams.where(title: "#{page.id}_Section_3c").first
      if feed_stream.present?
        s = StreamEntity.create({
          "entity_value": "#{self.view_cast_id}",
          "entity_type": "view_cast_id",
          "stream_id": feed_stream.id,
          "is_excluded": false
        })
        feed_stream.reload
        feed_stream.publish_cards
        feed_stream.publish_rss
      end
    end
    true
  end


  #PRIVATE
  private


end
