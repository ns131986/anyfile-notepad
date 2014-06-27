class EditorController < GOauthController
  require 'json'
  
  def get_file_flow
    begin
      file_hash = @gapi.get_file_data(params[:id])
      content = file_hash['content']
    rescue NoMethodError
      redirect_to new_g_file_path
      flash[:error]= "Document content was not downloaded. Google docs are not currently supported."
      return
    rescue Exceptions::FileTooBigError
      redirect_to new_g_file_path
      flash[:error]= "Document content was not downloaded. Files larger then 1M are not supported."
      return
    rescue Google::APIClient::ClientError
      flash[:error] = "Couldn't get file. Are you sure it exists ?"
      redirect_to new_g_file_path
      return
    rescue Google::APIClient::ServerError
      flash[:error] = "A fatal error occured when communicating with Google's servers. We tried our best to recover it."
      redirect_to request.original_url
      return
    end

    if not content.nil?
      begin
        content.encode("UTF-8")
      rescue
        content = content.force_encoding("UTF-8")
        if not content.valid_encoding?
          content = content.unpack("C*").pack("U*")
        end
        flash.now[:warn] = "Content encoding has been changed by force. This could corrupt your file. Think about it before saving."
      end
    end
    
    @file = GFile.new(:id => params[:id], :title => file_hash['title'], :content=> content , :type => file_hash['mimeType'],:new_revision => true, :persisted => true,)
    
    syntax_mode = @preferences.get_preference('syntaxes')[@file.extension]
    if not syntax_mode.nil?
      @file.syntax = Syntax.find_by_ace_js_mode(syntax_mode)
    end

    
    @title = @file.title
    
    MimeType.add_if_not_known file_hash['mimeType'], @user.name
  end
  
  def new
    @title = "New file"
    if params[:folder_id]
      @file = GFile.new(:type => 'text/plain', :persisted => false, :folder_id => params[:folder_id])
    else
      @file = GFile.new(:type => 'text/plain', :persisted => false, :folder_id => 'root')
    end
  end
  
  def create
    params[:g_file][:gapi] = @gapi
    @file = GFile.new(params[:g_file])
    @success = @file.create
    if @success
      respond_to do |format|
        format.html {
          flash[:notice] = "Your file has been created."
          redirect_to edit_g_file_path @file.id
        }
        format.js{
          flash[:notice] = "Your file has been created."
        }
      end
    else
      respond_to do |format|
        format.html {render 'new'}
        format.js
      end
    end
    
  end
  
  def show
    get_file_flow
  end
  
	def edit
    get_file_flow
  end
  
  def update
    params[:g_file][:gapi] = @gapi
    @file = GFile.new(params[:g_file])
    @title = @file.title
    
    success = @file.save
    if success
      respond_to do |format|
        format.html {
          flash[:notice] = "Your file has been saved."
          redirect_to edit_g_file_path params[:id]
        }
        format.js{
          flash.now[:notice] = "Your file has been saved."
        }
      end
    else
      respond_to do |format|
        format.html {render 'edit'}
        format.js
      end
    end
  end

end
