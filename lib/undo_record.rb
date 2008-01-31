require 'zlib'

class UndoRecord < ActiveRecord::Base
  
  belongs_to :undo_action
  before_create :set_revision_number
  
  CREATE = 0
  UPDATE = 1
  DESTROY = 2
  
  # Create a revision record based on a record passed in. The attributes of the original record will
  # be serialized. If it uses the acts_as_revisionable behavior, associations will be revisioned as well.
  def initialize (operation, record)
    super()
    self.undoable_type = record.class.name
    self.undoable_id = record.id 
    associations = record.class.undoable_associations if record.class.respond_to?(:undoable_associations)
    # self.data = Zlib::Deflate.deflate(Marshal.dump(serialize_attributes(record, associations)))
    self.data = Marshal.dump(serialize_attributes(record, associations))
    self.operation = operation
  end

  # Returns the attributes that are saved in the revision.
  def revision_attributes
    return nil unless self.data
    uncompressed = Zlib::Inflate.inflate(self.data) rescue uncompressed = self.data # backward compatibility with uncompressed data
    Marshal.load(uncompressed)
  end

  def inspect
    "\#<#{self.class} id=#{id} operation=#{operation} undo_action_id=#{undo_action_id} undoable_type=#{undoable_type} undoable_id=#{undoable_id} revision=#{revision} attributes=#{revision_attributes.inspect}>"
  end
  
  # Restore the revision to the original record. If any errors are encountered restoring attributes, they
  # will be added to the errors object of the restored record.
  def restore(update=true)
    restore_class = self.undoable_type.constantize
    attrs, association_attrs = attributes_and_associations(restore_class, self.revision_attributes)
    
    record = restore_class.new
    record.instance_variable_set(:@new_record, nil) if update
    attrs.each_pair do |key, value|
      begin
        record.send("#{key}=", value)
      rescue
        record.errors.add(key.to_sym, "could not be restored to #{value.inspect}")
      end
    end
    
    association_attrs.each_pair do |association, attribute_values|
      restore_association(record, association, attribute_values)
    end
    
    return record
  end
  
  # Find a specific revision record.
  # revision = 0 for deleted
  def self.find_revision (klass, id, revision)
    find(:first, :conditions => {:undoable_type => klass.to_s, :undoable_id => id, :revision => revision})
  end
  
  # Truncate the revisions for a record. Available options are :limit and :max_age.
  def self.truncate_revisions (undoable_type, undoable_id, options)
    return unless options[:limit] or options[:minimum_age]
    
    conditions = ['undoable_type = ? AND undoable_id = ?', undoable_type.to_s, undoable_id]
    if options[:minimum_age]
      conditions.first << ' AND created_at <= ?'
      conditions << options[:minimum_age].ago
    end
    
    start_deleting_revision = find(:first, :conditions => conditions, :order => 'revision DESC', :offset => options[:limit])
    if start_deleting_revision
      delete_all(['undoable_type = ? AND undoable_id = ? AND revision <= ?', undoable_type.to_s, undoable_id, start_deleting_revision.revision])
    end
  end

  def un_create
    restore_class = self.undoable_type.constantize
    record = restore_class.destroy(undoable_id)
  end

  def un_destroy
    record = self.restore(false)
    record.save!
  end

  def undo_update
    #find previous UndoRecord
    debugger
    previous = UndoRecord.find :first,
      {:conditions => 
        ['undoable_type = ? AND undoable_id = ? AND revision = ?', undoable_type.to_s, undoable_id, revision-1]}
    record = previous.restore(true)
    record.save!
  end

  def redo_update
    record = self.restore(true)
    record.save!
  end

  def undo
    case operation
      when CREATE then un_create
      when UPDATE then undo_update
      when DESTROY then un_destroy
    end
  end

  def redo
    case operation
      when CREATE then un_destroy
      when UPDATE then redo_update
      when DESTROY then un_create
    end
  end

  private
  
  def set_revision_number
    unless self.revision
      last_revision = self.class.maximum(:revision, :conditions => {:undoable_type => self.undoable_type, :undoable_id => self.undoable_id}) || 0
      self.revision = last_revision + 1
    end
  end

  def serialize_attributes (record, undoable_associations, already_serialized = {})
    return if already_serialized["#{record.class}.#{record.id}"]
    
    if (record.kind_of?(Hash))
      attrs = record.dup
    else
      attrs = record.attributes.dup
      already_serialized["#{record.class}.#{record.id}"] = true
    
      if undoable_associations.kind_of?(Hash)
        record.class.reflections.values.each do |association|
          if undoable_associations[association.name]
            if association.macro == :has_many
              attrs[association.name] = record.send(association.name).collect{|r| serialize_attributes(r, undoable_associations[association.name], already_serialized)}
            elsif association.macro == :has_one
              associated = record.send(association.name)
              unless associated.nil?
                attrs[association.name] = serialize_attributes(associated, undoable_associations[association.name], already_serialized)
              else
                attrs[association.name.to_s] = nil
              end
            elsif association.macro == :has_and_belongs_to_many
              attrs[association.name] = record.send("#{association.name.to_s.singularize}_ids".to_sym)
            end
          end
        end
      end
    end
    
    return attrs
  end
  
  def attributes_and_associations (klass, hash)
    attrs = {}
    association_attrs = {}
    
    hash.each_pair do |key, value|
      if klass.reflections.include?(key)
        association_attrs[key] = value
      else
        attrs[key] = value
      end
    end
    
    return [attrs, association_attrs]
  end
  
  def restore_association (record, association, attributes)
    reflection = record.class.reflections[association]
    associated_record = nil
    
    begin
      if reflection.macro == :has_many
        if attributes.kind_of?(Array)
          record.send(association).clear
          attributes.each do |association_attributes|
            restore_association(record, association, association_attributes)
          end
        else
          associated_record = record.send(association).build
          associated_record.id = attributes['id']
          exists = associated_record.class.find(associated_record.id) rescue nil
          associated_record.instance_variable_set(:@new_record, nil) if exists
        end
      elsif reflection.macro == :has_one
        associated_record = reflection.klass.new
        associated_record.id = attributes['id']
        exists = associated_record.class.find(associated_record.id) rescue nil
        associated_record.instance_variable_set(:@new_record, nil) if exists
        record.send("#{association}=", associated_record)
      elsif reflection.macro == :has_and_belongs_to_many
        record.send("#{association.to_s.singularize}_ids=", attributes)
      end
    rescue => e
      record.errors.add(association, "could not be restored from the revision: #{e.message}")
    end
    
    return unless associated_record
    
    attrs, association_attrs = attributes_and_associations(associated_record.class, attributes)
    attrs.each_pair do |key, value|
      begin
        associated_record.send("#{key}=", value)
      rescue
        associated_record.errors.add(key.to_sym, "could not be restored to #{value.inspect}")
        record.errors.add(association, "could not be restored from the revision") unless record.errors[association]
      end
    end
    
    association_attrs.each_pair do |key, values|
      restore_association(associated_record, key, values)
    end
  end
  
end
