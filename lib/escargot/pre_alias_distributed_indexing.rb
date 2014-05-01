module Escargot

  module PreAliasDistributedIndexing

    def PreAliasDistributedIndexing.load_dependencies
      require 'resque'
    end

    def PreAliasDistributedIndexing.create_index_for_model(model)
      load_dependencies

      model.select(model.primary_key).find_in_batches do |batch|
        Escargot.queue_backend.enqueue(IndexDocuments, model.to_s, batch.map(&:id))
      end
    end

    class IndexDocuments
      @queue = :indexing

      def self.perform(model_name, ids)
        model = model_name.constantize
        batch = model.where(model.primary_key => ids)
        LocalIndexing.batch_index_records(batch, model)
      rescue Exception => e
        if e.message =~ /SIGTERM/
          Resque.enqueue(self, model_name, ids)
        else
          raise
        end
      end
    end

  end

end
