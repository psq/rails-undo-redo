require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'zlib'

class TestModel < ActiveRecord::Base
  acts_as_undoable
end

describe "UndoAction" do

  before(:each) do
    UndoManager.current = nil
    undo_manager = UndoManager.current
    @undo_action = UndoAction.new
    @undo_action.description = "description"
    undo_manager.undo_actions << @undo_action
    
  end
  
  it "should call undo on each undo_records" do
    undo_record1 = mock(:undo_record)
    undo_record2 = mock(:undo_record)
    @undo_action.should_receive(:undo_records).and_return [undo_record1, undo_record2]
    undo_record1.should_receive(:undo)
    undo_record2.should_receive(:undo)
    @undo_action.undo  
  end

  it "should call redo on each undo_records" do
    undo_record1 = mock(:undo_record)
    undo_record2 = mock(:undo_record)
    @undo_action.should_receive(:undo_records).and_return [undo_record1, undo_record2]
    undo_record1.should_receive(:redo)
    undo_record2.should_receive(:redo)
    @undo_action.redo  
  end

  it "should create an UndoRecord for each change" do
    model = TestModel.new
    changes = [{:operation => 1, :model => model}, {:operation => 2, :model => model}]
    undo_record = UndoRecord.new(UndoRecord::CREATE, model)
    UndoRecord.should_receive(:new).twice.and_return undo_record
    @undo_action.change(changes)
    
    @undo_action.undo_records.size.should == 1  
  end
end
