module Escargot
  class Configuration
    class << self
      
      def env
        if defined?(Rails)
          Rails.env
        elsif ENV['RACK_ENV']
          ENV['RACK_ENV']
        elsif defined?(Sinatra::Application)
          Sinatra::Application.environment.to_s
        end
      end
    
      def settings
        user_configuration || { "host" => 'localhost', "port" => '9200', "timeout" => 20 }
      end
    
      def user_configuration
        path = File.join(app_root, "config", "elasticsearch.yml")
        if File.exists?(path) && env_hash = YAML.load(File.open(path, 'r').read)[env]
          env_hash
        else
          nil
        end
      end
      
      def app_root=(root_path)
        @app_root = root_path
      end
    
      def app_root
        @app_root ||= case 
        when defined?(Rails)
          Rails.root
        when defined?(Sinatra)
          Sinatra::Application.root
        else
          Dir.pwd
        end
      end
      
    end
  end
end