require 'cloudstrg/cloudstrg'

class GdriveStrg < CloudStrg::CloudStorage
  require 'google/api_client'

  CLIENT_ID = "867108581948.apps.googleusercontent.com"
  CLIENT_SECRET = "Z3TXaBvx36ex8RRD-Wu-3PGK"
  SCOPES = [
      'https://www.googleapis.com/auth/drive.file', # we will only see the files createdby this app
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/userinfo.profile'
  ]

  def initialize params
    @client = Google::APIClient.new
    @drive_api = @client.discovered_api('drive', 'v2')
    @auth_api = @client.discovered_api('oauth2', 'v2')
    
    @client.authorization.client_id = CLIENT_ID
    @client.authorization.client_secret = CLIENT_SECRET
    #@client.authorization.redirect_uri = @secrets.redirect_uris.first
    @client.authorization.scope = SCOPES
  end

  def config params
    @client.authorization.redirect_uri =  params[:redirect]
    
    @username = params[:username]
    user = Cloudstrguser.find_by_name(@username)

    session = params[:session]
    
    @client.authorization.update_token!(:access_token => session[:gdrive_access_token] , #:access_token => user.gdrive_access_token, 
                                     :refresh_token => user.gdrive_refresh_token, 
                                     :expires_in => user.gdrive_expires_in, 
                                     :issued_at => user.gdrive_issued_at)
    if @client.authorization.refresh_token && @client.authorization.expired?
      @client.authorization.fetch_access_token!
      session[:gdrive_access_token] = @client.authorization.access_token
      # user.gdrive_access_token = @client.authorization.access_token
      user.gdrive_refresh_token = @client.authorization.refresh_token
      user.gdrive_expires_in = @client.authorization.expires_in
      user.gdrive_issued_at = @client.authorization.issued_at
      user.save()
    end
    

    if params[:code]
      authorize_code(params[:code])
      
      session[:gdrive_access_token] = @client.authorization.access_token
      # user.gdrive_access_token = @client.authorization.access_token
      user.gdrive_refresh_token = @client.authorization.refresh_token
      user.gdrive_expires_in = @client.authorization.expires_in
      user.gdrive_issued_at = @client.authorization.issued_at
      user.save()
    elsif params[:error] # User denied the oauth grant
      puts "Denied: #{params[:error]}"
    end

    if not authorized?
      #user.gdrive_refresh_token = @client.authorization.refresh_token
      #user.save
      return session, auth_url
    end
    return session, false
  end

  def create_file params
    filename = params[:filename]
    filename += ".json" if not filename.include? ".json"

    file = @drive_api.files.insert.request_schema.new({'title' => filename, 'description' => 'Netlab scenario', 'mimeType' => 'text/json'})
    media=Google::APIClient::UploadIO.new(StringIO.new(params[:file_content]), 'text/json')
    r = @client.execute(:api_method => @drive_api.files.insert, :body_object => file, :media => media, :parameters => {'uploadType' => 'multipart', 'alt' => 'json'})
    if r.status != 200
      return false
    end
    true
  end

  def create_folder params
  end

  def get_file params
    r = @client.execute!(:api_method => @drive_api.files.get, :parameters => {'fileId' => params[:fileid]})
    if r.status != 200
      return nil, nil, nil
    end
    filename = r.data.title
    r = @client.execute!(:uri => r.data.download_url)
    if r.status != 200
      return nil, nil, nil
    end

    return filename, params[:fileid], r.body
  end

  def update_file params
    filename = params[:filename]
    filename += ".json" if not filename.include? ".json"

    file = @drive_api.files.insert.request_schema.new({'title' => filename, 'description' => 'Netlab scenario', 'mimeType' => 'text/json'})
    media=Google::APIClient::UploadIO.new(StringIO.new(params[:file_content]), 'text/json')
    r = @client.execute(:api_method => @drive_api.files.update, :body_object => file, :media => media, :parameters => {'fileId' => params[:fileid], 'uploadType' => 'multipart', 'alt' => 'json'})
    if r.status != 200
      return false
    end
    true
  end

  def remove_file params
    r = @client.execute!(:api_method => @drive_api.files.delete, :parameters => {'fileId' => params[:fileid]})
  end

  def list_files
    r=@client.execute!(:api_method => @drive_api.files.list)
    if r.status != 200
      return []
    end
    
    lines = []
    r.data.items.each do |line|
      lines.append([line.title, line.id]) if line.title.include? ".json"
    end
    return lines
  end



  def authorized?
    return @client.authorization.refresh_token && @client.authorization.access_token
  end

  def authorize_code(authorization_code)
    @client.authorization.code = authorization_code
    @client.authorization.fetch_access_token!
  end

  def auth_url(state = '')
    return @client.authorization.authorization_uri().to_s
  end
end
