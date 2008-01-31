require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

ActiveRecord::Schema.define(:version => 0) do
  create_table :test_models, :force => true do |t|
    t.column "name", :string
    t.column "count", :integer
  end    
end

class TestModel < ActiveRecord::Base
  acts_as_undoable
end


describe "Basic Undo Redo" do
  def change(description, &block)
    UndoManager.current.change(description, &block)
  end
  
  before(:each) do
    TestModel.destroy_all
    UndoManager.current = nil
  end

  it "should record create model" do
    change("create model") do
      test_model = TestModel.create(:name => 'joe', :count =>4)
    end
  
    undo_manager = UndoManager.current
    undo_manager.undo_actions.count(:all).should == 1
    undoAction = undo_manager.undo_actions.find(1)
    undoAction.undo_records.count.should == 1
  end
  
  it "should record update model" do
    test_model = TestModel.create(:name => 'joe', :count =>4)
    test_model.save!
    change("create model") do
      test_model.name = "jane"
      test_model.save
    end
  
    undo_manager = UndoManager.current
    undo_manager.undo_actions.count(:all).should == 1
    undoAction = undo_manager.undo_actions[0]
    undoAction.undo_records.count.should == 1
  end
  
  it "should record delete model" do
    test_model = TestModel.create(:name => 'joe', :count =>4)
    change("create model") do
      test_model.destroy
    end
  
    undo_manager = UndoManager.current
    undo_manager.undo_actions.count(:all).should == 1
    undoAction = undo_manager.undo_actions[0]
    undoAction.undo_records.count.should == 1
  end

  it "should record all operations on model" do
    change("lots of modfications") do
      test_model1 = TestModel.create(:name => 'joe', :count =>4)
      test_model1.name = "jane"
      test_model1.save
      test_model2 = TestModel.create(:name => 'jake', :count =>4)
    end
    change("more modifications and destroy") do
      test_model = TestModel.find(1)
      test_model.name = "aimee"
      test_model.save
      test_model.destroy
    end

    undo_manager = UndoManager.current
    undo_manager.undo_actions.count(:all).should == 2
    undoAction0 = undo_manager.undo_actions[0]
    undoAction0.undo_records.count.should == 3
    undoAction1 = undo_manager.undo_actions[1]
    undoAction1.undo_records.count.should == 2
  end

  it "should undo create model, then redo" do
    change("create model") do
      test_model = TestModel.create(:name => 'joe', :count =>4)
    end
    UndoManager.current.undo_description.should == "create model"
    UndoManager.current.redo_description.should == nil
    UndoManager.current.undo
    TestModel.count(:all).should == 0
    UndoManager.current.undo_description.should == nil
    UndoManager.current.redo_description.should == "create model"
    UndoManager.current.redo
    TestModel.count(:all).should == 1
  end

  it "should undo update model, then redo" do
    change("create model") do
      test_model = TestModel.create(:name => 'joe', :count =>4)
    end
    change("update model") do
      test_model = TestModel.find 1
      test_model.name = "aimee"
      test_model.save
    end
    UndoManager.current.undo_description.should == "update model"
    UndoManager.current.redo_description.should == nil
    UndoManager.current.undo
    test_model = TestModel.find 1
    test_model.name.should == "joe"
    UndoManager.current.undo_description.should == "create model"
    UndoManager.current.redo_description.should == "update model"
    UndoManager.current.redo
    test_model.reload
    test_model.name.should == "aimee"
  end

  it "should undo destroy model, then redo" do
    test_model = TestModel.create(:name => 'joe', :count =>4)
    change("delete model") do
      test_model.destroy
    end
    UndoManager.current.undo
    TestModel.count(:all).should == 1
    UndoManager.current.redo
    TestModel.count(:all).should == 0
  end

  it "should clear redo when new change is recorded"

end
