module Historical::Models
  class ModelDiff
    include MongoMapper::EmbeddedDocument
    extend Historical::MongoMapperEnhancements
    class_inheritable_accessor :historical_callbacks

    validates_associated :changes

    key :_type,       String

    belongs_to_active_record :record, :polymorphic => true, :required => true
  
    key :diff_type,   String,   :required => true

    many        :changes,       :class_name => "Historical::Models::AttributeDiff"
    
    delegate :creation?, :update?, :to => :diff_type_inquirer
  
    def new_version
      _parent_document
    end
  
    def old_version
      new_version.previous
    end

    def self.from_versions(from, to)
      return from_creation(to) if from.nil?
      
      generate_from_version(from, 'update').tap do |d|
        from.record.attribute_names.each do |attr_name|
          attr = attr_name.to_sym
          next if Historical::IGNORED_ATTRIBUTES.include? attr
    
          old_value, new_value = from[attr], to[attr]
         
          Historical::Models::AttributeDiff.specialized_for(d, attr).new.tap do |ad|
            ad.attribute_type = Historical::Models::AttributeDiff.detect_attribute_type(d, attr)
            ad.parent = d
            ad.old_value = old_value
            ad.new_value = new_value
            ad.attribute = attr.to_s
            d.changes << ad
          end if old_value != new_value
        end
      end
    end

    def self.from_creation(to)
      generate_from_version(to)
    end
    
    before_validation_on_create do |r|
      if cbs = r.class.historical_callbacks
        cbs.each do |c|
          c.call(r)
        end
      end
      
      true
    end
  
    protected
    
    def diff_type_inquirer
      ActiveSupport::StringInquirer.new(diff_type)
    end
    
    def self.historical_callback(&block)
      raise "no block given" unless block_given?

      self.historical_callbacks ||= []
      self.historical_callbacks << block
    end
    
  
    def self.generate_from_version(version, type = 'creation')
      for_class(version.record.class).new.tap do |d|
        d.diff_type   = type
        d.record_id   = version._record_id
        d.record_type = version._record_type
      end
    end
    
    def self.for_class(source_class)
      Historical::Models::Pool.pooled(Historical::Models::Pool.pooled_name(source_class, self)) do
        Class.new(self).tap do |cls|
          source_class.historical_customizations.each do |customization|
            cls.instance_eval(&customization)
          end
        end
      end
    end
  end
end
