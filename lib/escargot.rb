require 'elasticsearch'
require 'escargot/configuration'
require 'escargot/activerecord_ex'
require 'escargot/elasticsearch_ex'
require 'escargot/local_indexing'
require 'escargot/distributed_indexing'
require 'escargot/queue_backend/base'
require 'escargot/queue_backend/resque'

module Escargot
  def self.register_model(model)
    return unless model.table_exists?
    @indexed_models ||= []
    @indexed_models.delete(model) if @indexed_models.include?(model)
    @indexed_models << model
  end

  def self.indexed_models
    @indexed_models || []
  end

  def self.queue_backend
    @queue ||= Escargot::QueueBackend::Rescue.new
  end
  
  def self.flush_all_indexed_models
    @indexed_models = []
  end

  # search_hits returns a raw ElasticSearch::Api::Hits object for the search results
  # see #search for the valid options
  def self.search_hits(query, options = {}, call_by_instance_method = false)
    unless call_by_instance_method
      if (options[:classes])
        models = Array(options[:classes])
      else
        register_all_models
        models = @indexed_models
      end
      options = options.merge({:index => models.map(&:index_name).join(',')})
    end
    
    if query.kind_of?(Hash)
      query_dsl = query.delete(:query_dsl)
      query = {:query => query} if (query_dsl.nil? || query_dsl)
    end
    Escargot.connection.search(query, options)
  end
  
  def self.search_api(query, options = {}, call_by_instance_method = false)
    unless call_by_instance_method
      if (options[:classes])
        models = Array(options[:classes])
      else
        register_all_models
        models = @indexed_models
      end
      options = options.merge({:index => models.map(&:index_name).join(',')})
    end
    
    if query.kind_of?(Hash)
      query_dsl = query.delete(:query_dsl)
      # query = {:query => query} if (query_dsl.nil? || query_dsl)
    end
    Escargot.connection.search(query, options)
  end

  # search returns a will_paginate collection of ActiveRecord objects for the search results
  #
  # see ElasticSearch::Api::Index#search for the full list of valid options
  #
  # note that the collection may include nils if ElasticSearch returns a result hit for a
  # record that has been deleted on the database  
  def self.search(query, options = {}, call_by_instance_method = false)
    if options[:method] == :search_api
      hits = Escargot.search_api(query, options, call_by_instance_method)
    else
      hits = Escargot.search_hits(query, options, call_by_instance_method)
    end
    hits_ar = hits.map{|hit| hit.to_activerecord}
    results = WillPaginate::Collection.new(hits.current_page, hits.per_page, hits.total_entries)
    results.replace(hits_ar)
    results
  end

  # counts the number of results for this query.
  def self.search_count(query = "*", options = {}, call_by_instance_method = false)
    unless call_by_instance_method
      if (options[:classes])
        models = Array(options[:classes])
      else
        register_all_models
        models = @indexed_models
      end
      options = options.merge({:index => models.map(&:index_name).join(',')})
    end
    Escargot.connection.count(query, options)
  end
  
  def self.establish_connection
    unless File.exists?(Configuration.app_root + "/config/elasticsearch.yml")
      Rails.logger.warn("No config/elastic_search.yaml file found, connecting to localhost:9200") if defined?(Rails)
      $elastic_search_client = ElasticSearch.new("localhost:9200")
    else
      config = YAML.load_file(Configuration.app_root + "/config/elasticsearch.yml")
      $elastic_search_client = ElasticSearch.new(config["host"] + ":" + config["port"].to_s, :timeout => 20)
    end
    
    return $elastic_search_client
  end
    
  def self.reconnect!
    $elastic_search_client.disconnect! rescue
    establish_connection
  end
  
  def self.connection
    $elastic_search_client || establish_connection
  end
  
  private
    def self.register_all_models
      models = []
      # Search all Models in the application Rails
      Dir[File.join("#{Configuration.app_root}/app/models".split(/\\/), "**", "*.rb")].each do |file|
        model = file.gsub(/#{Configuration.app_root}\/app\/models\/(.*?)\.rb/,'\1').classify.constantize
        unless models.include?(model)
          require file
        end
        models << model
      end
    end
end


#-------------------------------------------------------------------------------
require 'escargot' 
require 'escargot/rails/init_commun'

# preserve rails 2.x compatibility
(Rails::VERSION::MAJOR == 3) ? (require 'escargot/rails/railtie') : (require 'escargot/rails/init')
#-------------------------------------------------------------------------------
