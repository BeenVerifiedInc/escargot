module Escargot
  
  module LocalIndexing
    def LocalIndexing.create_index_for_model(model)
      model = model.constantize if model.kind_of?(String)

      index_version = model.create_index_version

      model.find_in_batches do |batch|
        batch.each do |record|
          record.local_index_in_elastic_search(:index => index_version)
        end
      end

      Escargot.connection.deploy_index_version(model.index_name, index_version)
    end
    
    def LocalIndexing.batch_index_records(batch, model, index_version = nil)
      Escargot.connection.bulk do |bulk_client|
        batch.each do |record|
          options = { }
          options[:index] ||= (index_version || model.index_name)
          options[:type]  ||= model.name.underscore.singularize.gsub(/\//,'-')
          options[:id]    ||= record.id.to_s
          
          object_hash = record.respond_to?(:indexed_object_hash) ? record.indexed_object_hash : record.to_hash
          bulk_client.index(object_hash, options)
        end
      end
    end
    
  end

end
