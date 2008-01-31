ActiveRecord::Base.send(:include, Undoable)
ActionView::Base.send(:include, UndoableHelper)
ActionController::Base.send(:include, UndoableHelper)
