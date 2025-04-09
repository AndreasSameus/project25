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
    rating = db.execute("SELECT AVG(rating) FROM user_entry_rel WHERE entry_id = ?",params[:id]).first
    count = db.execute("SELECT COUNT(rating) FROM user_entry_rel WHERE entry_id = ?",params[:id]).first
    if rating["AVG(rating)"] == nil
        result.merge!("rating" => "?")
        result.merge!("count"  => "0")
    else
        result.merge!("rating" => "#{rating["AVG(rating)"].round(2)}")
        result.merge!("count"  => "#{count["COUNT(rating)"]}")
    end
    p result
    slim(:"entry",locals:{entry:result})
end

get("/create") do
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    admin_lvl = db.execute("SELECT admin_lvl FROM users WHERE username = ?",session[:user]).first
    result = db.execute("SELECT * FROM pending")
    slim(:"add",locals:{add:[result,admin_lvl]})
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
    admin_lvl = db.execute("SELECT admin_lvl FROM users WHERE username = ?",session[:user]).first
    if img && img[:filename]
        filename = img[:filename]
        file = img[:tempfile]
        path = "./public/img/#{filename}"
        File.open(path, 'wb') do |f|
            f.write(file.read)
        end
    end
    if admin_lvl["admin_lvl"] == 0
        result = db.execute("INSERT INTO entries (title,creator,type,genre,date,img) VALUES(?,?,?,?,?,?)",[entryname,creator,type,genre,date,filename])
    else
        result = db.execute("INSERT INTO pending (title,creator,type,genre,date,img) VALUES(?,?,?,?,?,?)",[entryname,creator,type,genre,date,filename])
    end

    redirect("/create")
end

post("/accept") do
    request_id = params[:request_id]
    entryname = params[:entryname]
    creator = params[:creator]
    type = params[:type]
    genre = params[:genre]
    date = params[:date]
    img = params[:file]
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    result = db.execute("INSERT INTO entries (title,creator,type,genre,date,img) VALUES(?,?,?,?,?,?)",[entryname,creator,type,genre,date,img])
    result = db.execute("DELETE FROM pending where id = ?",request_id)
    redirect("/create")
end

post("/delete") do 
    request_id = params[:request_id]
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    admin_lvl = db.execute("SELECT admin_lvl FROM users WHERE username = ?",session[:user]).first
    result = db.execute("DELETE FROM pending where id = ?",request_id)
    redirect("/create")
end

get("/profile/:username") do
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    result = db.execute("SELECT id FROM users WHERE username = ?",params[:username]).first
    avg_rating = db.execute("SELECT AVG(rating) FROM user_entry_rel WHERE user_id = ?",result["id"]).first
    user_entries = db.execute("SELECT entry_id FROM user_entry_rel WHERE user_id = ?",result["id"])
    array = []
    for i in user_entries
        array << i["entry_id"]
    end
    typearray = []
    for i in array
        type = db.execute("SELECT type FROM entries WHERE id = ?",i).first
        typearray << type["type"]
    end
    result.merge!("rating" => "#{avg_rating["AVG(rating)"].round(2)}")
    result.merge!(typearray.tally)
    slim(:"profile",locals:{profile:result})
end

post("/entries/rate") do
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true

    user_id = db.execute("SELECT id FROM users WHERE username = ?", session[:user]).first["id"]
    entry_id = params[:entry_id].to_i
    rating = params[:rating].to_i

    existing = db.execute("SELECT * FROM user_entry_rel WHERE user_id = ? AND entry_id = ?", [user_id, entry_id])

    if !existing.empty?
        db.execute("UPDATE user_entry_rel SET rating = ? WHERE user_id = ? AND entry_id = ?", [rating, user_id, entry_id])
    else
        db.execute("INSERT INTO user_entry_rel (user_id, entry_id, rating) VALUES (?, ?, ?)", [user_id, entry_id, rating])
    end

    redirect("/entries/#{params[:entry_id]}")
end