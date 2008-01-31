class CreateUndoRecords < ActiveRecord::Migration
  
  def self.up
    create_table :undo_records do |t|
      t.column :operation, :integer
      t.column :undoable_type, :string, :limit => 100
      t.column :undoable_id, :integer
      t.column :revision, :integer
      t.column :data, :binary, :limit => 5.megabytes
      t.column :created_at, :timestamp
      t.column :undo_action_id, :integer, :null => false
    end
    
    add_index :undo_records, [:undoable_type, :undoable_id, :revision], :name => :undoable, :unique => true

    create_table :undo_actions do |t|
      t.column :description, :string, :limit => 100
      t.column :undo_manager_id, :integer, :null => false
    end

    create_table :undo_managers do |t|
      t.column :current_action_id, :integer
    end
  end
  
  def self.down
    drop_table :undo_managers
    drop_table :undo_actions
    drop_table :undo_records
  end

end
