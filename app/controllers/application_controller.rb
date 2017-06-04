class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :sudo

  def sudo_pykih_admin
    redirect_to root_url, notice: "Permission denied." if !current_user.is_admin_from_pykih
  end

  private

  def sudo
  	if user_signed_in?
  		if params[:account_id].present?
  			@account = Account.friendly.find(params[:account_id])
  		elsif controller_name == "accounts" and params[:id].present?
  			@account = Account.friendly.find(params[:id])
  		end
  		@on_an_account_page = (@account.present? and @account.id.present?)
      if @on_an_account_page
        @permission = current_user.permission_object(@account.id)
        @people_count = @account.users.count
        @pending_invites_count = @account.permission_invites.count
        if @permission.blank?
          redirect_to root_url, notice: "Permission denied."
        end
      end
  	end
  end

end