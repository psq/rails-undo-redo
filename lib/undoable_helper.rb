module UndoableHelper

def undo_description
  UndoManager.current.undo_description
end

def redo_description
  UndoManager.current.redo_description
end

def change(description, &block)
  UndoManager.current.change(description, &block)
end

def undo
  UndoManager.current.undo
end

def redo
  UndoManager.current.redo
end

end