require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

get('/')  do
    slim(:home)
end 

get("/entries") do
    title = params[:title]
    genre = params[:genre]
    type = params[:type]
    creator = params[:creator]
    date = params[:date]
    ASC = params[:ASC]
    DESC = params[:DESC]

    if genre
        main_order = genre
    elsif type
        main_order = type
    elsif creator
        main_order = creator
    elsif date
        main_order = date
    else
        main_order = "title"
    end

    if DESC
        hej = DESC
    else
        hej = "ASC"
    end
    
    p main_order
    p hej

    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    result = db.execute("SELECT * FROM entries ORDER BY ? ?",[main_order,hej])
    slim(:"entries",locals:{entries:result})
  
end