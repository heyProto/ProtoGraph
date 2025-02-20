class Api::V1::PagesController < ApiController
  before_action :set_page, only: [:update]

  def create
    @page = Page.new(page_params)
    @page.folder = @folder
    @page.site = @site
    @page.updator = @user
    @page.creator = @user
    if @page.save
        render json: {page: @page.as_json(methods: [:html_url]), message: "Page created successfully"}, status: 200
    else
        render json: {errors: @page.errors.as_json}, status: 422
    end
  end

  def update
    # params -> page{content[{data, card-id, template-id, htmlString}]}
    @page.updated_by = @user.id
    p_params = page_params
    respond_to do |format|
      modified_attributes = @page.changed - ["content", "updated_by", "updated_at"]
      if(modified_attributes.any?)
        format.json {
            render json: {error: "Attempted to update illegal attributes: " << modified_attributes.to_s }, status: 500
          }
          format.html {
            redirect_to edit_write_site_story_path(@site, @page, folder_id: @page.folder_id), alert: "Attempted to update illegal attributes: " << modified_attributes.to_s and return
          }
      else
        if @page.update_attributes(page_params)
          format.json {
            render json: {redirect_url: edit_write_site_story_url(@site, @page, folder_id: @page.folder_id) }, status: 200
          }
          format.html {
            redirect_to edit_write_site_story_path(@site, @page, folder_id: @page.folder_id), notice: 'Page editted successfully' and return
          }
        else
          format.json {
            render json: {error: @page.errors.full_messages }, status: 500
          }
          format.html {
            redirect_to edit_write_site_story_path(@site, @page, folder_id: @page.folder_id), alert: @page.errors.full_messages and return
          }
        end
      end
    end
    # @page.updated_by = current_user.id

    # p_params = page_params
    # if params[:commit] == 'Publish'
    #   p_params["status"] = 'published'
    # end

    # # removes cover image if it is not specified (?)
    # if p_params.has_key?('cover_image_attributes') and !p_params['cover_image_attributes'].has_key?("image")
    #   p_params.delete('cover_image_attributes')
    # end

    # # perform updates
    # if @page.update_attributes(page_params)
    #   format.json { respond_with_bip(@page) }
    #   format.html {
    #     redirect_to edit_assemble_site_story_path(@site, @page, folder_id: @page.folder_id)
    #   }
    # else
    #   format.json { respond_with_bip(@page) }
    #   format.html {
    #     @page.publish = @page.status == 'published'
    #     if @page.status != "draft"
    #       if @page.template_page.name == "article"
    #         redirect_to edit_write_site_story_path(@site, @page, folder_id: @page.folder_id), alert: @page.errors.full_messages
    #         return
    #       end
    #     end
    #   }
    # end
  end

  private

  def set_page
    @page = Page.friendly.find(params[:id])
  end

  def page_params
    params.require(:page).permit(:id, :site_id, :folder_id, :folder_id, :headline, :meta_keywords, :meta_description, :summary, :template_page_id, :byline_id, :one_line_concept, :hide_byline,
    :reported_from_country, :reported_from_state, :reported_from_district, :reported_from_city,
   :cover_image_url, :cover_image_url_7_column, :cover_image_url_facebook, :cover_image_url_square, :cover_image_alignment, :content,
   :is_sponsored, :is_interactive, :has_data, :has_image_other_than_cover, :has_audio, :has_video, :status, :published_at, :url, :html_key,
   :ref_category_series_id, :ref_category_intersection_id, :ref_category_sub_intersection_id, :view_cast_id, :page_object_url, :created_by,
   :updated_by, :english_headline, :due, :description, :cover_image_id_4_column, :cover_image_id_3_column, :cover_image_id_2_column, :cover_image_credit, :share_text_facebook,
     :share_text_twitter, :publish, :prepare_cards_for_assembling, :format, :importance, :external_identifier, collaborator_lists: [], cover_image_attributes: [:image, :site_id, :is_cover, :created_by,
     :updated_by])
  end
end
