require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'
require_relative("./model/module.rb")
enable :sessions

include Model

# Helper functions related to the current user's session
# @see #logged_in?
# @see #current_user
# @see #current_user_id
# @see #current_admin_lvl
helpers do
    # Checks if the user is logged in
    # @return [Boolean] Returns `true` if a user is logged in, otherwise `false`
    def logged_in?
      !!session[:user]
    end
  
    # Retrieves the current logged-in user's username
    # @return [String, nil] Returns the username of the current logged-in user or `nil` if not logged in
    def current_user
      session[:user]
    end
  
    # Retrieves the current logged-in user's ID
    # @return [Integer, nil] Returns the user ID of the current logged-in user or `nil` if not logged in
    def current_user_id
      session[:user_id]
    end
  
    # Retrieves the current logged-in user's admin level
    # @return [Integer, nil] Returns the admin level of the current logged-in user or `nil` if not logged in
    def current_admin_lvl
      session[:admin_lvl]
    end
end

# Before filter to ensure user is logged in to access restricted paths.
# @see #logged_in?
before do
    restricted_paths = ['/create']
    if restricted_paths.include?(request.path_info) && !logged_in?
        p "You Need To Login To Access This"
        redirect ('/showlogin')
    end
end

# Route to display the home page
# @return [String] The rendered HTML for the index page
get('/') do
    slim(:index)
end

# Route to display the user registration form
# @return [String] The rendered HTML for the registration form
get('/register') do
    slim(:"users/create")
end

# Route to display the login form
# @return [String] The rendered HTML for the login form
get('/showlogin') do
    slim(:login)
end

# Post route for handling user login
# @param [String] username The user's input username
# @param [String] password The user's input password
# @return [String] A message indicating success or failure of the login attempt
post('/login') do
    username = params[:username]
    password = params[:password]
    result = find_user_by_username(username)
    failed_attempts = session[:failed_attempts] || 0
    since_last_failed_attempt = session[:since_last_failed_attempt] || Time.now.to_i

    if failed_attempts >= 3 && Time.now.to_i - since_last_failed_attempt < 300
        "Too many login attempts. Please try again later."
    else
        if result && BCrypt::Password.new(result["password"]) == password
            session[:user] = result["username"]
            session[:user_id] = result["id"]
            session[:admin_lvl] = result["admin_lvl"]
            session[:failed_attempts] = 0
            session[:since_last_failed_attempt] = nil
            redirect('/')
        else
            "Wrong password"
            session[:failed_attempts] = failed_attempts + 1
            session[:since_last_failed_attempt] = Time.now.to_i
            redirect('/showlogin')
        end
    end
end

# Post route to create a new user
# @param [String] username The username of the new user
# @param [String] password The password of the new user
# @param [String] password_confirm The confirmation password
# @return [String] A message indicating success or failure of the registration
post('/users/new') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]

    if username != ""
        if password != ""
            if password == password_confirm
                password_digest = BCrypt::Password.create(password)
                insert_user(username, password_digest, 1)
            else
                "The passwords didn't match"
            end
        end
    end
    redirect('/')
end

# Post route to handle sorting entries
# @param [Hash] params The request parameters containing sorting preferences
# @return [String] A redirect to the sorted entries list
post('/entries') do
    sort_fields = ["title", "genre", "type", "creator", "date"]
    sort_fields.each do |field|
        if params[field]
            session[:main_order] = field
            break
        end
    end

    sort_directions = ["ASC", "DESC"]
    sort_directions.each do |direction|
        if params[direction]
            session[:order] = direction
            break
        end
    end

    session[:main_order] ||= "title"
    session[:order] ||= "ASC"

    redirect('/entries')
end

# Route to display all entries with optional sorting
# @return [String] The rendered HTML for the list of entries
get('/entries') do
    entries = if session[:main_order] && session[:order]
                select_all_ordered("entries", session[:main_order], session[:order])
                else
                select_all("entries")
                end
    slim(:"entries/index", locals: { entries: entries })
end

# Route to display an individual entry
# @param [Integer] id The ID of the entry to display
# @return [String] The rendered HTML for the individual entry page
get('/entries/:id') do
    id = params[:id]
    entry = get_entry(id)
    rating = get_average_rating(id)
    count = get_rating_count(id)

    if rating["AVG(rating)"].nil?
        entry["rating"] = "?"
        entry["count"] = "0"
    else
        entry["rating"] = rating["AVG(rating)"].round(2).to_s
        entry["count"] = count["COUNT(rating)"].to_s
    end

    slim(:"entries/show", locals: { entry: entry })
end

# Route for admin to create new entries or manage pending entries
# @return [String] The rendered HTML for creating or managing entries
get('/create') do
    admin_lvl = get_admin_level(session[:user])
    pending = select_all("pending")
    slim(:"entries/new", locals: { add: [pending, admin_lvl] })
end

# Post route to create a new entry (for admin or users with certain privileges)
# @param [Hash] params The entry details, including name, creator, type, genre, date, and file
# @return [String] A redirect to the entry management page
post('/create') do
    entry = [
        params[:entryname],
        params[:creator],
        params[:type],
        params[:genre],
        params[:date],
        nil
    ]

    if params[:file] && params[:file][:filename]
        filename = params[:file][:filename]
        file = params[:file][:tempfile]
        path = "./public/img/#{filename}"
        File.open(path, 'wb') { |f| f.write(file.read) }
        entry[5] = filename
    end

    admin_lvl = get_admin_level(session[:user])
    if admin_lvl["admin_lvl"].to_i == 0
        insert_entry(entry)
    else
        insert_pending(entry)
    end

    redirect('/create')
end

# Post route to accept a pending entry and promote it to an official entry
# @param [Hash] params The details of the entry to accept
# @return [String] A redirect to the entry management page
post('/accept') do
    entry = [
        params[:entryname],
        params[:creator],
        params[:type],
        params[:genre],
        params[:date],
        params[:file] 
    ]
    insert_entry(entry)
    delete_pending(params[:request_id])
    redirect('/create')
end

# Post route to delete a pending entry
# @param [Integer] request_id The ID of the pending entry to delete
# @return [String] A redirect to the entry management page
post('/delete') do
    delete_pending(params[:request_id])
    redirect('/create')
end

# Route to view a user's profile
# @param [String] username The username of the user whose profile to view
# @return [String] The rendered HTML for the user's profile page
get('/profile/:username') do
    if logged_in?
        user_id = get_user_id(params[:username])
        avg_rating = get_user_average_rating(user_id)["AVG(rating)"]
        user_entries = get_user_entries(user_id)

        type_array = user_entries.map { |e| get_entry_type(e["entry_id"])["type"] }
        profile_data = {
            "rating" => avg_rating&.round(2).to_s,
            **type_array.tally
        }
    else 
        redirect ('/showlogin')
    end

    slim(:"profile/index", locals: { profile: profile_data })
end

# Post route for users to rate an entry
# @param [Integer] entry_id The ID of the entry being rated
# @param [Integer] rating The rating being given to the entry
# @return [String] A redirect to the individual entry page
post('/entries/rate') do
    user_id = get_user_id(session[:user])
    entry_id = params[:entry_id].to_i
    rating = params[:rating].to_i
    if user_id != session[:user_id]
        redirect("/")
    else
        rate_entry(user_id, entry_id, rating)
    end
    redirect("/entries/#{entry_id}")
end

# Post route to delete an entry
# @param [Integer] entry_id The ID of the entry to delete
# @return [String] A redirect to the entries list page
post('/entries/delete') do
    entry_id = params[:entry_id].to_i
    delete_entry(entry_id)
    redirect("/entries")
end