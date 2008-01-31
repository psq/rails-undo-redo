class UndoAction < ActiveRecord::Base
  has_many  :undo_records
  belongs_to :undo_manager

  def change(changes)
    changes.each do |c|
      undo_record = UndoRecord.new(c[:operation], c[:model])
      undo_records << undo_record
      undo_record.save!
    end
  end
  
  def undo
    undo_records.reverse_each do |undo_record|
      undo_record.undo
    end
  end
  
  def redo
    undo_records.reverse_each do |undo_record|
      undo_record.redo
    end
  end
end