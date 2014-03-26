module Escargot
  class Railtie < ::Rails::Railtie
    initializer 'escargot.init' do
      ActiveSupport.on_load(:active_record) do
        ElasticSearch::Api::Hit.class_eval { include Escargot::HitExtensions }
        ElasticSearch::Client.class_eval { include Escargot::AdminIndexVersions }
        include(Escargot::ActiveRecordExtensions)
      end
    end

    rake_tasks do
      load 'escargot/tasks/escargot.tasks'
    end

    generators do
      load "generators/escargot_install/escargot_install_generator.rb"
    end
  end
end
