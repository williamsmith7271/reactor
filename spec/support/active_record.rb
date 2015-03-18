require 'active_record'

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"

ActiveRecord::Migrator.up "db/migrate"

ActiveRecord::Migration.create_table :auctions do |t|
  t.string :name
  t.datetime :start_at
  t.datetime :close_at
  t.boolean :we_want_it
  t.integer :pet_id

  t.timestamps null: false
end

ActiveRecord::Migration.create_table :subscribers do |t|
  t.string :event_name
  t.string :type

  t.timestamps null: false
end

ActiveRecord::Migration.create_table :pets do |t|
  t.integer :awesomeness
  t.string :type


  t.timestamps null: false
end

ActiveRecord::Migration.create_table :arbitrary_models do |t|
  t.integer :awesomeness

  t.timestamps null: false
end

class Pet < ActiveRecord::Base
end

class ArbitraryModel < ActiveRecord::Base
end
