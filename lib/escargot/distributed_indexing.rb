
module Escargot

  module DistributedIndexing

    def DistributedIndexing.load_dependencies
      require 'resque'
    end

    def DistributedIndexing.create_index_for_model(model)
      load_dependencies

      index_version = model.create_index_version

      model.find_in_batches(:select => model.primary_key) do |batch|
        Escargot.queue_backend.enqueue(IndexDocuments, model.to_s, batch.map(&:id), index_version)
      end

      Escargot.queue_backend.enqueue(DeployNewVersion, model.index_name, index_version)
    end

    class IndexDocuments
      @queue = :indexing

      def self.perform(model_name, ids, index_version)
        model = model_name.constantize
        # model.find(:all, :conditions => {model.primary_key => ids}).each do |record|
        #   record.local_index_in_elastic_search(:index => index_version)
        # end
        batch = model.find(:all, :conditions => { model.primary_key => ids })
        LocalIndexing.batch_index_records(batch, model, index_version)
      end
    end

    class ReIndexDocuments
      @queue = :nrt

      def self.perform(model_name, ids)
        model = model_name.constantize
        ids_found = []
        model.find_all_by_id(ids).each do |record|
          record.local_index_in_elastic_search
          ids_found << record.id
        end

        (ids - ids_found).compact.each do |id|
          begin
            model.delete_id_from_index(id)
          rescue
            # Since we're in a resque job here, maybe something else already cleaned this guy up.
            # Don't crash if it's already been deleted elsewhere.
          end
        end
      end
    end

    class DeployNewVersion
      @queue = :indexing
      def self.perform(index, index_version)
        Escargot.connection.deploy_index_version(index, index_version)
      end
    end
  end

end
