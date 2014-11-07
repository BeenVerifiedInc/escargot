# desc "Explaining what the task does"
# task :elastic_rails do
#   # Task goes here
# end

namespace :escargot do
  desc "indexes the models"
  task :index, [:models] => [:environment, :load_all_models] do |t, args|
    each_indexed_model(args) do |model|
      puts "Indexing #{model}"
      Escargot::LocalIndexing.create_index_for_model(model)
    end
  end

  desc "indexes the models"
  task :distributed_index, [:models] => [:environment, :load_all_models] do |t, args|
    each_indexed_model(args) do |model|
      puts "Indexing #{model}"
      Escargot::DistributedIndexing.create_index_for_model(model)
    end
  end
  
  desc "indexes the models LIVE LIKE BOSS"
  task :pre_alias_distributed_index, [:models] => [:environment, :load_all_models] do |t, args|
    each_indexed_model(args) do |model|
      puts "Indexing #{model}"
      index_version = model.create_index_version
      begin
        Escargot.connection.deploy_index_version(model.index_name, index_version)
      rescue => e
        if e.message.include?("an index exists with the same name as the alias")
          puts "Index with the alias name already exists.  Deleting it and trying again..."
          Escargot.connection.delete_index(model.index_name)
          retry
        else
          raise
        end
      end
      Escargot::PreAliasDistributedIndexing.create_index_for_model(model)
    end
  end
  
  desc "prunes old index versions for this models"
  task :prune_versions, [:models] => [:environment, :load_all_models] do |t, args|
    each_indexed_model(args) do |model|
      Escargot.connection.prune_index_versions(model.index_name)
    end
  end
  
  task :load_all_models do
    Rails.application.eager_load!
  end
  
  private
    def each_indexed_model(args)
      if args[:models]
        models = args[:models].split(",").map{|m| m.classify.constantize}
      else
        models = Escargot.indexed_models
      end
      models.each{|m| yield m}
    end
end
