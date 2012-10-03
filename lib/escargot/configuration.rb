module Escargot
  class Configuration
    class << self
      
      def env
        Rails.env
      end
    
      def settings
        user_configuration || {"host" => 'localhost', "port" => '9200', "timeout" => 20}
      end
    
      def user_configuration
        path = File.join(app_root, "/config/elasticsearch.yml")
        if File.exists?(path) && env_hash = YAML.load(File.open(path, 'r').read)[env]
          env_hash
        else
          nil
        end
      end
    
      def app_root
        if defined?(Rails.root)
          Rails.root
        elsif defined?(Sinatra)
          Sinatra::Application.root
        end
      end
      
    end
  end
end