module Escargot
  class Configuration
    def self.app_root
      if defined?(Rails.root)
        Rails.root
      elsif defined?(Sinatra)
        Sinatra::Application.root
      end
    end
  end
end