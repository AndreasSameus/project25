require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

get('/')  do
    slim(:home)
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