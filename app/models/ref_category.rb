# == Schema Information
#
# Table name: ref_categories
#
#  id                 :integer          not null, primary key
#  site_id            :integer
#  category           :string(255)
#  name               :string(255)
#  parent_category_id :integer
#  stream_url         :text(65535)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class RefCategory < ApplicationRecord
    #CONSTANTS
    #CUSTOM TABLES
    #GEMS
    #ASSOCIATIONS
    belongs_to :site
    #ACCESSORS
    #VALIDATIONS
    validates :name, presence: true, uniqueness: true
    validates :category, inclusion: {in: ["genre", "sub_genre", "series"]}
    validates :parent_category_id, presence: true, if: "category==sub_genre"
    #CALLBACKS
    #SCOPE
    #OTHER
    #PRIVATE
    private
end
