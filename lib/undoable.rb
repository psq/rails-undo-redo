module Undoable
  
  def self.included (base)
    base.extend(UndoableMethods)
  end
  
  module UndoableMethods
    # Calling acts_as_undoable will inject the undoable behavior into the class.
    def acts_as_undoable
      include InstanceMethods

      alias_method :create_without_undo, :create
      alias_method :create, :create_with_undo

      alias_method :update_without_undo, :update
      alias_method :update, :update_with_undo

      alias_method :destroy_without_undo, :destroy
      alias_method :destroy, :destroy_with_undo
    end
  end
  
  module InstanceMethods
    def create_with_undo(*args)
      UndoManager.current.create_model(self)
      create_without_undo(*args)
    end

    def update_with_undo(*args)
      UndoManager.current.update_model(self)
      update_without_undo(*args)
    end

    def destroy_with_undo(*args)
      UndoManager.current.destroy_model(self)
      destroy_without_undo(*args)
    end
  end
  
end