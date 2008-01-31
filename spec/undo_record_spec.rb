require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'zlib'

describe "UndoRecord" do
  
  class TestUndoableRecord
    attr_accessor :attributes
    
    def initialize (attributes = {})
      @attributes = attributes
    end
    
    def self.reflections
      @reflections || {}
    end
    
    def self.reflections= (vals)
      @reflections = vals
    end
  
    def id
      attributes['id']
    end
    
    def id= (val)
      attributes['id'] = val
    end
    
    def name= (val)
      attributes['name'] = val
    end
    
    def value= (val)
      attributes['value'] = val
    end
    
    def self.undoable_associations
      nil
    end
  end
  
  class TestUndoableAssociationRecord < TestUndoableRecord
    def self.reflections
      @reflections || {}
    end
    
    def self.reflections= (vals)
      @reflections = vals
    end
  end
  
  class TestUndoableSubAssociationRecord < TestUndoableRecord
    def self.reflections
      @reflections || {}
    end
    
    def self.reflections= (vals)
      @reflections = vals
    end
  end
  
  before(:each) do
    TestUndoableRecord.reflections = nil
    TestUndoableAssociationRecord.reflections = nil
    TestUndoableSubAssociationRecord.reflections = nil
  end
  
  it "should set the revision number before it creates the record" do
    UndoRecord.delete_all
    undo_action = UndoAction.new
    undo_manager = UndoManager.create
    undo_manager.undo_actions << undo_action
    undo_action.save!
    revision1 = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    undo_action.undo_records << revision1
    revision1.save!
    revision2 = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    undo_action.undo_records << revision2
    revision2.save!
    revision1.revision.should == 1
    revision2.revision.should == 2
    revision2.revision = 20
    revision2.save!
    revision3 = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    undo_action.undo_records << revision3
    revision3.save!
    revision3.revision.should == 21
    UndoRecord.delete_all
  end
  
  it "should serialize all the attributes of the original model" do
    attributes = {'id' => 1, 'name' => 'revision', 'value' => 5}
    original = TestUndoableRecord.new(attributes)
    revision = UndoRecord.new(UndoRecord::CREATE, original)
    revision.undoable_id.should == 1
    revision.undoable_type.should == "TestUndoableRecord"
    revision.revision_attributes.should == attributes
  end
  
  it "should serialize all the attributes of undoable has_many associations" do
    attributes = {'id' => 1, 'name' => 'revision', 'value' => Time.now}
    association_attributes_1 = {'id' => 2, 'name' => 'association_1'}
    association_attributes_2 = {'id' => 3, 'name' => 'association_2'}
    original = TestUndoableRecord.new(attributes)
    undoable_associations = [TestUndoableAssociationRecord.new(association_attributes_1), TestUndoableAssociationRecord.new(association_attributes_2)]
    undoable_associations_reflection = stub(:association, :name => :undoable_associations, :macro => :has_many, :options => {:dependent => :destroy})
    non_undoable_associations_reflection = stub(:association, :name => :non_undoable_associations, :macro => :has_many, :options => {})
    
    TestUndoableRecord.should_receive(:undoable_associations).and_return(:undoable_associations => true)
    TestUndoableRecord.reflections = {:undoable_associations => undoable_associations_reflection, :non_undoable_associations => non_undoable_associations_reflection}
    original.should_not_receive(:non_undoable_associations)
    original.should_receive(:undoable_associations).and_return(undoable_associations)
    
    revision = UndoRecord.new(UndoRecord::CREATE, original)
    revision.revision_attributes.should == attributes.merge(:undoable_associations => [association_attributes_1, association_attributes_2])
  end
  
  it "should serialize all the attributes of undoable has_one associations" do
    attributes = {'id' => 1, 'name' => 'revision', 'value' => Date.today}
    association_attributes = {'id' => 2, 'name' => 'association_1'}
    original = TestUndoableRecord.new(attributes)
    undoable_association = TestUndoableAssociationRecord.new(association_attributes)
    undoable_association_reflection = stub(:association, :name => :undoable_association, :macro => :has_one, :options => {:dependent => :destroy})
    non_undoable_association_reflection = stub(:association, :name => :non_undoable_association, :macro => :has_one, :options => {})
    
    TestUndoableRecord.should_receive(:undoable_associations).and_return(:undoable_association => true)
    TestUndoableRecord.reflections = {:undoable_association => undoable_association_reflection, :non_undoable_association => non_undoable_association_reflection}
    original.should_not_receive(:non_undoable_association)
    original.should_receive(:undoable_association).and_return(undoable_association)
    
    revision = UndoRecord.new(UndoRecord::CREATE, original)
    revision.revision_attributes.should == attributes.merge(:undoable_association => association_attributes)
  end
  
  it "should serialize all undoable has_many_and_belongs_to_many associations" do
    attributes = {'id' => 1, 'name' => 'revision'}
    original = TestUndoableRecord.new(attributes)
    undoable_associations_reflection = stub(:association, :name => :undoable_associations, :macro => :has_and_belongs_to_many, :options => {:dependent => :destroy})
    non_undoable_associations_reflection = stub(:association, :name => :non_undoable_associations, :macro => :has_and_belongs_to_many, :options => {})
    
    TestUndoableRecord.should_receive(:undoable_associations).and_return(:undoable_associations => true)
    TestUndoableRecord.reflections = {:undoable_associations => undoable_associations_reflection, :non_undoable_associations => non_undoable_associations_reflection}
    original.should_receive(:undoable_association_ids).and_return([2, 3, 4])
    
    revision = UndoRecord.new(UndoRecord::CREATE, original)
    revision.revision_attributes.should == attributes.merge(:undoable_associations => [2, 3, 4])
  end
  
  it "should serialize undoable associations of undoable associations with :dependent => :destroy" do
    attributes = {'id' => 1, 'name' => 'revision', 'value' => Time.now}
    association_attributes_1 = {'id' => 2, 'name' => 'association_1'}
    association_attributes_2 = {'id' => 3, 'name' => 'association_2'}
    original = TestUndoableRecord.new(attributes)
    association_1 = TestUndoableAssociationRecord.new(association_attributes_1)
    association_2 = TestUndoableAssociationRecord.new(association_attributes_2)
    undoable_associations = [association_1, association_2]
    undoable_associations_reflection = stub(:association, :name => :undoable_associations, :macro => :has_many, :options => {:dependent => :destroy})
    sub_association_attributes = {'id' => 4, 'name' => 'sub_association_1'}
    sub_association = TestUndoableSubAssociationRecord.new(sub_association_attributes)
    sub_association_reflection = stub(:sub_association, :name => :sub_association, :macro => :has_one, :options => {:dependent => :destroy})
    
    TestUndoableRecord.should_receive(:undoable_associations).and_return(:undoable_associations => {:sub_association => true})
    TestUndoableRecord.reflections = {:undoable_associations => undoable_associations_reflection}
    TestUndoableAssociationRecord.reflections = {:sub_association => sub_association_reflection}
    original.should_receive(:undoable_associations).and_return(undoable_associations)
    association_1.should_receive(:sub_association).and_return(sub_association)
    association_2.should_receive(:sub_association).and_return(nil)
    
    revision = UndoRecord.new(UndoRecord::CREATE, original)
    revision.revision_attributes.should == attributes.merge(:undoable_associations => [association_attributes_1.merge(:sub_association => sub_association_attributes), association_attributes_2.merge('sub_association' => nil)])
  end
  
  it "should be able to restore the original model" do
    attributes = {'id' => 1, 'name' => 'revision', 'value' => 5}
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new(attributes))
    revision.data = Zlib::Deflate.deflate(Marshal.dump(attributes))
    restored = revision.restore
    restored.class.should == TestUndoableRecord
    restored.id.should == 1
    restored.attributes.should == attributes
  end
  
  it "should be able to restore associations" do
    restored = TestUndoableRecord.new
    attributes = {'id' => 1, 'name' => 'revision', 'value' => Time.now, :associations => {'id' => 2, 'value' => 'val'}}
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    revision.data = Zlib::Deflate.deflate(Marshal.dump(attributes))
    associations_reflection = stub(:associations, :name => :associations, :macro => :has_many, :options => {:dependent => :destroy})
    TestUndoableRecord.reflections = {:associations => associations_reflection}
    TestUndoableRecord.should_receive(:new).and_return(restored)
    revision.should_receive(:restore_association).with(restored, :associations, {'id' => 2, 'value' => 'val'})
    restored = revision.restore
  end
  
  it "should be able to restore the has_many associations" do
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    record = TestUndoableRecord.new
    
    associations_reflection = stub(:associations, :name => :associations, :macro => :has_many, :options => {:dependent => :destroy})
    TestUndoableRecord.reflections = {:associations => associations_reflection}
    associations = mock(:associations)
    record.should_receive(:associations).and_return(associations)
    associated_record = TestUndoableAssociationRecord.new
    associations.should_receive(:build).and_return(associated_record)
    
    revision.send(:restore_association, record, :associations, {'id' => 1, 'value' => 'val'})
    associated_record.id.should == 1
    associated_record.attributes.should == {'id' => 1, 'value' => 'val'}
  end
  
  it "should be able to restore the has_one associations" do
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    record = TestUndoableRecord.new
    
    association_reflection = stub(:associations, :name => :association, :macro => :has_one, :klass => TestUndoableAssociationRecord, :options => {:dependent => :destroy})
    TestUndoableRecord.reflections = {:association => association_reflection}
    associated_record = TestUndoableAssociationRecord.new
    TestUndoableAssociationRecord.should_receive(:new).and_return(associated_record)
    record.should_receive(:association=).with(associated_record)
    
    revision.send(:restore_association, record, :association, {'id' => 1, 'value' => 'val'})
    associated_record.id.should == 1
    associated_record.attributes.should == {'id' => 1, 'value' => 'val'}
  end
  
  it "should be able to restore the has_and_belongs_to_many associations" do
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    record = TestUndoableRecord.new
    
    associations_reflection = stub(:associations, :name => :associations, :macro => :has_and_belongs_to_many, :options => {})
    TestUndoableRecord.reflections = {:associations => associations_reflection}
    record.should_receive(:association_ids=).with([2, 3, 4])
    
    revision.send(:restore_association, record, :associations, [2, 3, 4])
  end
  
  it "should be able to restore associations of associations" do
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    record = TestUndoableRecord.new
    
    associations_reflection = stub(:associations, :name => :associations, :macro => :has_many, :options => {:dependent => :destroy})
    TestUndoableRecord.reflections = {:associations => associations_reflection}
    associations = mock(:associations)
    record.should_receive(:associations).and_return(associations)
    associated_record = TestUndoableAssociationRecord.new
    associations.should_receive(:build).and_return(associated_record)

    sub_associated_record = TestUndoableSubAssociationRecord.new
    TestUndoableAssociationRecord.should_receive(:new).and_return(sub_associated_record)
    sub_association_reflection = stub(:sub_association, :name => :sub_association, :macro => :has_one, :klass => TestUndoableAssociationRecord, :options => {:dependent => :destroy})
    TestUndoableAssociationRecord.reflections = {:sub_association => sub_association_reflection}
    associated_record.should_receive(:sub_association=).with(sub_associated_record)
    
    revision.send(:restore_association, record, :associations, {'id' => 1, 'value' => 'val', :sub_association => {'id' => 2, 'value' => 'sub'}})
    associated_record.id.should == 1
    associated_record.attributes.should == {'id' => 1, 'value' => 'val'}
    sub_associated_record.id.should == 2
    sub_associated_record.attributes.should == {'id' => 2, 'value' => 'sub'}
  end
  
  it "should be able to restore a record for a model that has changed and add errors to the restored record" do
    restored = TestUndoableRecord.new
    associated_record = TestUndoableAssociationRecord.new
    attributes = {'id' => 1, 'name' => 'revision', 'value' => Time.now, 'deleted_attribute' => 'abc', :bad_association => {'id' => 3, 'value' => :val}, :associations => {'id' => 2, 'value' => 'val', 'other' => 'val2'}}
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new)
    revision.data = Zlib::Deflate.deflate(Marshal.dump(attributes))
    TestUndoableRecord.should_receive(:new).and_return(restored)
 
    associations = mock(:associations)
    restored.should_receive(:associations).and_return(associations)
    # associated_record = TestUndoableAssociationRecord.new #psq: need to create before mock
    associations.should_receive(:build).and_return(associated_record)
    
    mock_record_errors = {}
    restored.stub!(:errors).and_return(mock_record_errors)
    mock_record_errors.should_receive(:add).with(:bad_association, "could not be restored to {\"id\"=>3, \"value\"=>:val}")
    mock_record_errors.should_receive(:add).with(:deleted_attribute, 'could not be restored to "abc"')
    mock_record_errors.should_receive(:add).with(:associations, 'could not be restored from the revision')
    
    mock_association_errors = mock(:errors)
    associated_record.stub!(:errors).and_return(mock_association_errors)
    mock_association_errors.should_receive(:add).with(:other, 'could not be restored to "val2"')
    
    associations_reflection = stub(:associations, :name => :associations, :macro => :has_many, :options => {:dependent => :destroy})
    TestUndoableRecord.reflections = {:associations => associations_reflection}
    
    restored = revision.restore
  end
  
  it "should be able to truncate the revisions for a record" do
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new(:name => 'name'))
    revision.revision = 20
    UndoRecord.should_receive(:find).with(:first, :conditions => ['undoable_type = ? AND undoable_id = ?', 'TestUndoableRecord', 1], :offset => 15, :order => 'revision DESC').and_return(revision)
    UndoRecord.should_receive(:delete_all).with(['undoable_type = ? AND undoable_id = ? AND revision <= ?', 'TestUndoableRecord', 1, 20])
    UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 15)
  end
  
  it "should be able to truncate the revisions for a record by age" do
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new(:name => 'name'))
    revision.revision = 20
    time = 2.weeks.ago
    minimum_age = stub(:integer, :ago => time, :to_i => 1)
    Time.stub!(:now).and_return(minimum_age)
    UndoRecord.should_receive(:find).with(:first, :conditions => ['undoable_type = ? AND undoable_id = ? AND created_at <= ?', 'TestUndoableRecord', 1, time], :offset => nil, :order => 'revision DESC').and_return(revision)
    UndoRecord.should_receive(:delete_all).with(['undoable_type = ? AND undoable_id = ? AND revision <= ?', 'TestUndoableRecord', 1, 20])
    UndoRecord.truncate_revisions(TestUndoableRecord, 1, :minimum_age => minimum_age)
  end
  
  it "should not truncate the revisions for a record if it doesn't have enough" do
    UndoRecord.should_receive(:find).with(:first, :conditions => ['undoable_type = ? AND undoable_id = ?', 'TestUndoableRecord', 1], :offset => 15, :order => 'revision DESC').and_return(nil)
    UndoRecord.should_not_receive(:delete_all)
    UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 15)
  end
  
  it "should not truncate the revisions for a record if no limit or minimum_age is set" do
    UndoRecord.should_not_receive(:find)
    UndoRecord.should_not_receive(:delete_all)
    UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => nil, :minimum_age => nil)
  end
  
  it "should be able to find a record by revisioned type and id" do
    revision = UndoRecord.new(UndoRecord::CREATE, TestUndoableRecord.new(:name => 'name'))
    UndoRecord.should_receive(:find).with(:first, :conditions => {:undoable_type => 'TestUndoableRecord', :undoable_id => 1, :revision => 2}).and_return(revision)
    UndoRecord.find_revision(TestUndoableRecord, 1, 2).should == revision
  end
  
  it "should really save the revision records to the database and restore without any mocking" do
    UndoRecord.delete_all
    UndoRecord.count.should == 0

    UndoRecord.delete_all
    undo_action = UndoAction.new
    undo_manager = UndoManager.create
    undo_manager.undo_actions << undo_action
    undo_action.save!
    
    attributes = {'id' => 1, 'value' => rand(1000000)}
    original = TestUndoableRecord.new(attributes)
    original.attributes['name'] = 'revision 1'
    revision1 = UndoRecord.new(UndoRecord::CREATE, original)
    undo_action.undo_records << revision1
    undo_action.save!
    first_revision = UndoRecord.find(:first)
    original.attributes['name'] = 'revision 2'
    revision2 = UndoRecord.new(UndoRecord::CREATE, original)
    undo_action.undo_records << revision2
    undo_action.save!
    original.attributes['name'] = 'revision 3'
    revision3 = UndoRecord.new(UndoRecord::CREATE, original)
    undo_action.undo_records << revision3
    undo_action.save!
    UndoRecord.count.should == 3
    
    record = UndoRecord.find_revision(TestUndoableRecord, 1, 1).restore
    record.class.should == TestUndoableRecord
    record.id.should == 1
    record.attributes.should == attributes.merge('name' => 'revision 1')
    
    UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 2)
    UndoRecord.count.should == 2
    UndoRecord.find_by_id(first_revision.id).should == nil
    UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 0, :minimum_age => 1.week)
    UndoRecord.count.should == 2
    UndoRecord.truncate_revisions(TestUndoableRecord, 1, :limit => 0)
    UndoRecord.count.should == 0
  end
  
end
