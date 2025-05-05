module Model


  def get_database
    db = SQLite3::Database.new("db/Sameusboxd.db")
    db.results_as_hash = true
    db.execute("PRAGMA foreign_keys = ON;")
    db
  end
    
  def select(columns, table, condition_column, condition_value)
    db = get_database
    db.execute("SELECT #{columns} FROM #{table} WHERE #{condition_column} = ?", condition_value)
  end
    
  def select_all(table)
    db = get_database
    db.execute("SELECT * FROM #{table}")
  end
    
  def select_all_ordered(table, order_column, direction)
    db = get_database
    db.execute("SELECT * FROM #{table} ORDER BY #{order_column} #{direction}")
  end
    
  def select_first(columns, table, condition_column, condition_value)
    select(columns, table, condition_column, condition_value).first
  end
    
  def insert_user(username, password_digest, admin_lvl)
    db = get_database
    db.execute("INSERT INTO users (username,password,admin_lvl) VALUES (?,?,?)", [username, password_digest, admin_lvl])
  end
    
  def find_user_by_username(username)
    select_first("*", "users", "username", username)
  end
    
  def insert_entry(entry)
    db = get_database
    db.execute("INSERT INTO entries (title,creator,type,genre,date,img) VALUES (?,?,?,?,?,?)", entry)
  end
    
  def insert_pending(entry)
    db = get_database
    db.execute("INSERT INTO pending (title,creator,type,genre,date,img) VALUES (?,?,?,?,?,?)", entry)
  end
    
  def delete_pending(id)
    db = get_database
    db.execute("DELETE FROM pending WHERE id = ?", id)
  end

  def delete_entry(id)
    db = get_database
    db.execute("DELETE FROM entries WHERE id = ?", id)
  end
    
  def get_user_id(username)
    select_first("id", "users", "username", username)["id"]
  end
    
  def get_admin_level(username)
    select_first("admin_lvl", "users", "username", username)
  end
    
  def get_entry(id)
    select_first("*", "entries", "id", id)
  end
    
  def get_average_rating(entry_id)
    db = get_database
    db.execute("SELECT AVG(rating) FROM user_entry_rel WHERE entry_id = ?", entry_id).first
  end
    
  def get_rating_count(entry_id)
    db = get_database
    db.execute("SELECT COUNT(rating) FROM user_entry_rel WHERE entry_id = ?", entry_id).first
  end
    
  def get_user_entries(user_id)
    db = get_database
    db.execute("SELECT entry_id FROM user_entry_rel WHERE user_id = ?", user_id)
  end
    
  def get_entry_type(entry_id)
    select_first("type", "entries", "id", entry_id)
  end
    
  def get_user_average_rating(user_id)
    db = get_database
    db.execute("SELECT AVG(rating) FROM user_entry_rel WHERE user_id = ?", user_id).first
  end
    
  def rate_entry(user_id, entry_id, rating)
    db = get_database

    existing = db.execute("SELECT * FROM user_entry_rel WHERE user_id = ? AND entry_id = ?", [user_id, entry_id])
    if existing.empty?
      db.execute("INSERT INTO user_entry_rel (user_id, entry_id, rating) VALUES (?, ?, ?)", [user_id, entry_id, rating])
    else
      db.execute("UPDATE user_entry_rel SET rating = ? WHERE user_id = ? AND entry_id = ?", [rating, user_id, entry_id])
    end
  end
end

