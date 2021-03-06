module I18nDocs
  class GoogleDriveManager

    require "rubygems"
    require "google/api_client"
    require "google_drive"

    def initialize(credentials)
      if credentials["oauth"]
        self.oauth = credentials["oauth"]
      end

      set_session
    end

    def get_files
      # Gets list of remote files.
      for file in session.files
        p file.title
      end
    end

    def upload(source_path, destination_title)

      if file = session.spreadsheet_by_title(destination_title)
        # update from spreadsheet
        raw_data = CSV.read(source_path)
        puts "    Upload #{destination_title}: started"
        update_all_cells(file,raw_data)
        puts "    Upload #{destination_title}: finished"
      else
        # create a new spreadsheet (convert => true)
        session.upload_from_file(source_path, destination_title, :convert => true)
      end
    end

    def download(spreadsheet_key, worksheet_title, destination_path)
      source_title = "#{spreadsheet_key}/#{worksheet_title}"
      # export from Google = import from app
      sheet = session.spreadsheet_by_key(spreadsheet_key)
      worksheet = sheet.worksheet_by_title(worksheet_title)
      if worksheet
        puts "    Download #{source_title}: started"
        worksheet.export_as_file(destination_path)
        puts "    Download #{source_title}: finished"
        true
      else
        puts "File #{source_title} was not found on Google Drive"
        false
      end
    end

    private

    attr_accessor :oauth, :access_token, :session

    # save and refresh the auth_token per: http://stackoverflow.com/questions/26789804/ruby-google-drive-gem-oauth2-saving

    def google_api_client_auth
      client = Google::APIClient.new
      auth = client.authorization
      auth.client_id     = oauth["client_id"]
      auth.client_secret = oauth["client_secret"]
      auth.scope =
          "https://www.googleapis.com/auth/drive " +
          "https://docs.google.com/feeds/ " +
          "https://docs.googleusercontent.com/ " +
          "https://spreadsheets.google.com/feeds/"
      auth.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
      [ client, auth ]
    end

    # get a new access token from google
    def get_new_access_token
      client, auth = google_api_client_auth
      print("1. Open this page:\n%s\n\n" % auth.authorization_uri)
      print("2. Enter the authorization code shown in the page: ")
      system( 'open "'+auth.authorization_uri+'"' )
      auth.code = $stdin.gets.chomp
      auth.fetch_access_token!
      auth.access_token
    end

    # refresh an existing access token
    def refresh_access_token(access_token)
      begin
        client, auth = google_api_client_auth
        auth.refresh_token = access_token
        auth.refresh!
        auth.access_token
      rescue
        puts "Failed to refresh Google OAuth access token"
        nil
      end
    end

    def read_access_token
      begin
        access_token = nil
        File.open('.i18n-docs-access-token', 'r') { |f| access_token = f.read }
        access_token
      rescue
        nil
      end
    end

    def write_access_token(access_token)
      File.open('.i18n-docs-access-token', 'w') { |f| f.write(access_token) }
    end

    def set_access_token
      # attempt to refresh our existing token
      access_token = read_access_token
      if access_token
        access_token = refresh_access_token(access_token)
      end
      # if reading and refreshing failed, then request a new one
      if access_token.nil?
        access_token = get_new_access_token
      end
      # write our token
      write_access_token(access_token)
      # set the token for this session
      self.access_token = access_token
    end

    def set_session
      set_access_token
      self.session = GoogleDrive.login_with_oauth(access_token)
    end

    def update_all_cells(drive_file,raw_data)
      puts "      getting worksheet: start"
      ws = drive_file.worksheets[0]
      puts "      getting worksheet: stop"

      # erase everything first
      (1..ws.num_rows).each do |row|
        (1..ws.num_cols).each do |col|
          ws[row,col] = ""
        end
      end

      # write then
      raw_data.each_with_index do |data, row|
        data.each_with_index do |val, col|
          ws[row + 1, col + 1] = val || ""
        end
      end

      begin
        # crop blank space around
        ws.max_cols = ws.num_cols
        ws.max_rows = ws.num_rows
        puts "      saving: start"
        ws.save
        puts "      saving: stop"
      rescue Nokogiri::XML::XPath::SyntaxError => e
        puts "Nokogiri Syntax error"
        puts "#{e.message}"
      rescue GoogleDrive::Error => e
        puts "Google Drive error"
        puts "#{e.message}"
      end
    end

  end
end
