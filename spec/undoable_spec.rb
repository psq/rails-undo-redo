require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require File.expand_path(File.dirname(__FILE__) + '/../init.rb')

describe "Undoable" do
  
  class TestUndoableModel
    include Undoable
    
    attr_accessor :id
    
    def create
    end

    def destroy
    end

    def update
    end
    
    # def self.has_many (name, options)
    #   @associations ||= {}
    #   @associations[name] = options
    # end
    # 
    # def self.associations
    #   @associations
    # end
    # 
    # private :update
    
    acts_as_undoable
  end
  
  it "should be able to inject undoable behavior onto ActiveRecord::Base" do
    ActiveRecord::Base.included_modules.should include(Undoable)
  end

  it "should be able to inject undoable behavior onto ActionView::Base" do
    ActionView::Base.included_modules.should include(UndoableHelper)
  end

  it "should be able to inject undoable behavior onto ActionController::Base" do
    ActionController::Base.included_modules.should include(UndoableHelper)
  end
  
end
