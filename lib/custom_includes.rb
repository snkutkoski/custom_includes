require "custom_includes/version"
require 'active_support/concern'
require 'active_record'

module CustomIncludes
  class Error < StandardError
  end

  extend ActiveSupport::Concern

  class_methods do
    def custom_belongs_to(obj, record_attr, obj_id, **options)
      relation_class = "#{self}::ActiveRecord_Relation".constantize
      relation_class.include(CustomIncludesRelation) unless relation_class.included_modules.include?(CustomIncludesRelation)

      unless self.method_defined?(record_attr) || self.column_names.include?(record_attr.to_s)
        raise CustomIncludes::Error.new("#{self} must have a #{record_attr} attribute")
      end

      @custom_belongs_to ||= {}
      @custom_belongs_to[obj] = { record_attr: record_attr, obj_id: obj_id, options: {raise_on_not_found: true}.merge(options) }

      define_method("#{obj}=") do |val|
        send("#{record_attr}=", val.send(obj_id))
      end

      define_method("#{obj}_included=") do |val|
        instance_variable_set("@#{obj}_included", val)
      end

      define_method(obj) do
        attr_val = send(record_attr)
        return nil unless attr_val
        included = instance_variable_get("@#{obj}_included")
        included && included.send(obj_id) != attr_val ? included : send("find_#{obj}")
      end
    end

    def custom_belongs_to_data
      @custom_belongs_to
    end

    def custom_includes(*args)
      all.custom_includes(*args)
    end
  end

  included do |mod|
    relation_class = "#{mod}::ActiveRecord_Relation".constantize
    relation_class.include(CustomIncludesRelation)
  end

  module CustomIncludesRelation
    attr_reader :custom_includes_loaded
    alias :custom_includes_loaded? :custom_includes_loaded

    ar_load = ActiveRecord::Relation.instance_method(:load)
    ar_reset = ActiveRecord::Relation.instance_method(:reset)

    def custom_includes(*args)
      check_if_method_has_arguments!(:custom_includes, args)
      spawn.custom_includes!(*args)
    end

    def custom_includes!(*args)
      self.custom_includes_values += args
      self
    end

    def custom_includes_values
      @custom_includes_values || []
    end

    def custom_includes_values=(value)
      @custom_includes_values = value
    end

    def perform_custom_includes
      model_class = @records.first.class

      custom_includes_values.each do |value|
        custom_includes_method = "#{value}_custom_includes"

        unless model_class.respond_to?(custom_includes_method)
          raise CustomIncludes::Error.new("#{model_class} must define a class method: #{custom_includes_method}(ids) to include #{value}")
        end

        belongs_to_data = model_class.custom_belongs_to_data[value]
        db_ids = Set.new(@records.map { |r| r.send(belongs_to_data[:record_attr]) }.compact).to_a
        objs = model_class.send(custom_includes_method, db_ids)

        objs_by_id = objs.reduce({}) do |objs_hash, obj|
          unless obj.respond_to?(belongs_to_data[:obj_id])
            raise CustomIncludes::Error.new("#{obj} was returned by the custom_includes method, but it does not have a(n) #{belongs_to_data[:obj_id]} method")
          end

          objs_hash[obj.send(belongs_to_data[:obj_id])] = obj
          objs_hash
        end

        @records.each do |r|
          record_attr = r.send(belongs_to_data[:record_attr])
          next unless record_attr
          included_obj = objs_by_id[record_attr]

          if belongs_to_data[:options][:raise_on_not_found] && !included_obj
            raise CustomIncludes::Error.new("Could not find an object to include with a #{belongs_to_data[:record_attr]} of #{record_attr}")
          end
          r.send("#{value}_included=", included_obj)
        end
      end

      @custom_includes_loaded = true
      @records
    end

    define_method(:load) do
      ar_load.bind(self).call
      perform_custom_includes if @records.present? && custom_includes_values.present? && !custom_includes_loaded?
      self
    end

    define_method(:reset) do
      ar_reset.bind(self).call
      @custom_includes_loaded = false
      self
    end
  end
end
