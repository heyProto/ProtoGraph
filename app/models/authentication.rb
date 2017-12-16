# == Schema Information
#
# Table name: authentications
#
#  id                  :integer          not null, primary key
#  account_id          :integer
#  provider            :string(255)
#  uid                 :string(255)
#  info                :text(65535)
#  name                :string(255)
#  email               :string(255)
#  access_token        :string(255)
#  access_token_secret :string(255)
#  refresh_token       :string(255)
#  token_expires_at    :datetime
#  created_by          :integer
#  updated_by          :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class Authentication < ApplicationRecord

  #CONSTANTS
  #CUSTOM TABLES
  #GEMS
  #ASSOCIATIONS
  has_one :creator, class_name: 'User', primary_key: 'created_by', foreign_key: 'id'
  #ACCESSORS
  #VALIDATIONS
  #CALLBACKS
  #SCOPE
  scope :fb_auth, -> {where provider: 'facebook'}
  scope :tw_auth, -> {where provider: 'twitter'}
  scope :insta_auth, -> {where provider: 'instagram'}
  #PRIVATE
  #OTHER

  class << self
    def from_omniauth(auth, account_id, current_user_id)
      where(provider: auth.provider, uid: auth.uid, account_id: account_id).first_or_initialize.tap do |a|
        a.account_id = account_id
        a.uid = auth.uid
        a.info = auth.info.to_json
        a.name = auth.info.name
        a.email = auth.info.email
        a.access_token = auth.credentials.token
        a.access_token_secret = auth.credentials.secret
        a.refresh_token = auth.credentials.refresh_token
        a.token_expires_at = Time.at(auth.credentials.expires_at) if auth.credentials.expires_at.present?
        a.created_by = current_user_id
        a.save!
      end
    end
  end

  def refresh_access_token
    if self.provider == 'facebook'
      if token_expired?
        refresh_token = RestClient.get 'https://graph.facebook.com/oauth/access_token', {
          params: {
            client_id: ENV['FACEBOOK_KEY'],
            client_secret: ENV['FACEBOOK_SECRET'],
            grant_type: 'fb_exchange_token',
            fb_exchange_token: self.access_token
            }
          }
        if refresh_token.code == 200
          response = JSON.parse(refresh_token)
          self.access_token = response['access_token']
          self.token_expires_at = Time.at(Time.now.to_i + response['expires_in'])
          self.save
        else
          # retry
          return refresh_access_token
        end
      end
    end
  end

  def token_expired?
    expiry = Time.at(self.token_expires_at)
    if expiry < Time.now # expired token, so we should quickly return
      return true
    else
      return false # token not expired. :D
    end
  end

end
