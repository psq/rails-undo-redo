class UndoManager < ActiveRecord::Base
  has_many :undo_actions, :dependent => :destroy, :order => 'id ASC'
  
  def initialize(attributes)
    super(attributes)
    @current_action_id = -1
  end

  def self.current
    @@curent ||= UndoManager.create()
  end

  def self.current=(undo_manager)
    @@curent = undo_manager
  end

  def create_model(model)
    @changes << {:operation => UndoRecord::CREATE, :model => model} if @changes
  end

  def update_model(model)
    @changes << {:operation => UndoRecord::UPDATE, :model => model} if @changes
  end

  def destroy_model(model)
    @changes << {:operation => UndoRecord::DESTROY, :model => model} if @changes
  end

  def change(description, &block)
    begin
      @changes = []

      block.call

      #clear now obsolete undo actions
      a = undo_actions.to_a
      a[(@current_action_id+1)..(a.size-1)].each do |undo_action|
        undo_actions.delete(undo_action)
      end
      
      undo_action = UndoAction.new
      undo_action.description = description
      undo_actions << undo_action
      
      undo_action.change(@changes)
      undo_action.save!

      @current_action_id += 1
      save!
    rescue => e
      throw e
    ensure
      @changes = nil
      return undo_action
    end
  end
  
  def undo
    if (@current_action_id >= 0)
      undo_action = undo_actions[@current_action_id]
      undo_action.undo
      @current_action_id -= 1
    end
  end

  def redo
    if (@current_action_id < undo_actions.count-1)
      @current_action_id += 1
      redo_action = undo_actions[@current_action_id]
      redo_action.redo
    end
  end
  
  def undo_description
    undo_actions[@current_action_id].description if (@current_action_id >= 0)
  end
  
  def redo_description
    undo_actions[@current_action_id+1].description if (@current_action_id < undo_actions.count-1)
  end

  def self.undo
    UndoManager.current.undo
  end
  
  def self.redo
    UndoManager.current.redo
  end
end
