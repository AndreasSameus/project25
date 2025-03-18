require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

get('/')  do
    slim(:home)
end 

get('/register') do
    slim(:register)
end

get("/showlogin") do
    slim(:login)
end

post("/login") do
    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["password"]
    user = result["username"]
  
    if BCrypt::Password.new(pwdigest) == password
      session[:user] = user
      redirect("/")
    else
      "Wrong password"
    end
end

post("/users/new") do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
  
    if password == password_confirm
      password_digest = BCrypt::Password.create(password)
      db = SQLite3::Database.new("db/Sameusboxd.db")
      db.execute("INSERT INTO users (username,password,admin_lvl) VALUES (?,?,?)", [username,password_digest,1])
      redirect("/")
    else
      "The passwords didnt match"
    end
end

post("/entries") do
    title = params[:title]
    genre = params[:genre]
    type = params[:type]
    creator = params[:creator]
    date = params[:date]
    ASC = params[:ASC]
    DESC = params[:DESC]

    main_order = [title, genre, type, creator, date]
    order = [ASC, DESC]

    for i in main_order
        if ["title","genre","type","creator","date"].include?(i)
            session[:main_order] = i
        end
    end

    for i in order
        if ["ASC","DESC"].include?(i)
            session[:order] = i
        end
    end

    if ! ["ASC","DESC"].include?(session[:order])
        session[:order] = "ASC"
    end

    if ! ["title","genre","type","creator","date"].include?(session[:main_order])
        session[:main_order] = "title"
    end

    redirect("/entries")
end

get("/entries") do  
    main_order = session[:main_order]
    order = session[:order]

    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    if main_order && order
        result = db.execute("SELECT * FROM entries ORDER BY #{main_order} #{order}")
    else 
        result = db.execute("SELECT * FROM entries")
    end
    slim(:"entries",locals:{entries:result})
end

get("/entries/:id") do
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM entries WHERE id = ?",params[:id]).first
    slim(:"entry",locals:{entry:result})
end

get("/create") do
    slim(:add)
end

post("/create") do
    entryname = params[:entryname]
    creator = params[:creator]
    type = params[:type]
    genre = params[:genre]
    date = params[:date]
    img = params[:file]

    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    if img && img[:filename]
        filename = img[:filename]
        file = img[:tempfile]
        path = "./public/img/#{filename}"
        File.open(path, 'wb') do |f|
            f.write(file.read)
        end
    end
    result = db.execute("INSERT INTO entries (title,creator,type,genre,date,img) VALUES(?,?,?,?,?,?)",[entryname,creator,type,genre,date,filename])
    redirect("/create")
end

get("/profile/:username") do
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    result = db.execute("SELECT id FROM users WHERE username = ?",params[:username])
    p result
    slim(:"profile",locals:{profile:result})
end

post("/entries/rate") do
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    user_id = db.execute("SELECT id FROM users WHERE username = ?",session[:user]).first["id"]
    entry_id = params[:entry_id].to_i
    rating = params[:rating].to_i
    p rating
    p user_id
    p entry_id
    db.execute("INSERT INTO user_entry_rel (user_id,entry_id,rating) VALUES (?,?,?)",[user_id,entry_id,rating])
    redirect("/entries/#{params[:entry_id]}")
end