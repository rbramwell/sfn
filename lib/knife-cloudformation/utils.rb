require 'knife-cloudformation'

module KnifeCloudformation
  # Utility classes and modules
  module Utils

    autoload :Output, 'knife-cloudformation/utils/output'
    autoload :StackParameterValidator, 'knife-cloudformation/utils/stack_parameter_validator'
    autoload :StackParameterScrubber, 'knife-cloudformation/utils/stack_parameter_scrubber'
    autoload :StackExporter, 'knife-cloudformation/utils/stack_exporter'

    # Debug helpers
    module Debug
      # Output helpers
      module Output
        # Write debug message
        #
        # @param msg [String]
        def debug(msg)
          puts "<KnifeCloudformation>: #{msg}" if ENV['DEBUG']
        end
      end

      class << self
        # Load module into class
        #
        # @param klass [Class]
        def included(klass)
          klass.class_eval do
            include Output
            extend Output
          end
        end
      end
    end

    # JSON helper methods
    module JSON

      # Attempt to load chef JSON compat helper
      #
      # @return [TrueClass, FalseClass] chef compat helper available
      def try_json_compat
        unless(@_json_loaded)
          begin
            require 'chef/json_compat'
          rescue
            require "#{ENV['RUBY_JSON_LIB'] || 'json'}"
          end
          @_json_loaded = true
        end
        defined?(Chef::JSONCompat)
      end

      # Convert to JSON
      #
      # @param thing [Object]
      # @return [String]
      def _to_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.to_json(thing)
        else
          JSON.dump(thing)
        end
      end

      # Load JSON data
      #
      # @param thing [String]
      # @return [Object]
      def _from_json(thing)
        if(try_json_compat)
          Chef::JSONCompat.from_json(thing)
        else
          JSON.read(thing)
        end
      end

      # Format object into pretty JSON
      #
      # @param thing [Object]
      # @return [String]
      def _format_json(thing)
        thing = _from_json(thing) if thing.is_a?(String)
        if(try_json_compat)
          Chef::JSONCompat.to_json_pretty(thing)
        else
          JSON.pretty_generate(thing)
        end
      end

    end

    extend JSON

    # Helper methods for string format modification
    module AnimalStrings

      # Camel case string
      #
      # @param string [String]
      # @return [String]
      def camel(string)
        string.to_s.split('_').map{|k| "#{k.slice(0,1).upcase}#{k.slice(1,k.length)}"}.join
      end

      # Snake case string
      #
      # @param string [String]
      # @return [Symbol]
      def snake(string)
        string.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase.to_sym
      end

    end

    extend AnimalStrings

    # Helper methods for SSH interactions
    module Ssher

      # Retrieve file from remote node
      #
      # @param address [String]
      # @param user [String]
      # @param path [String] remote file path
      # @param ssh_opts [Hash]
      # @return [String, NilClass]
      def remote_file_contents(address, user, path, ssh_opts={})
        require 'net/sftp'
        content = ''
        ssh_session = Net::SSH.start(address, user, ssh_opts)
        con = Net::SFTP::Session.new(ssh_session)
        con.loop{ con.opening? }
        f_handle = con.open!(path)
        data = ''
        count = 0
        while(data)
          data = nil
          request = con.read(f_handle, count, 1024) do |response|
            unless(response.eof?)
              if(response.ok?)
                count += 1024
                content << response[:data]
                data = true
              end
            end
          end
          request.wait
        end
        con.close!(f_handle)
        con.close_channel
        ssh_session.close
        content.empty? ? nil : content
      end

    end

    # Storage helpers
    module ObjectStorage

      # Write to file
      #
      # @param object [Object]
      # @param path [String] path to write object
      # @param directory [Fog::Storage::Directory]
      # @return [String] file path
      def file_store(object, path, directory)
        content = object.is_a?(String) ? object : Utils._format_json(object)
        directory.files.create(
          :identity => path,
          :body => content
        )
        loc = directory.service.service.name.split('::').last.downcase
        "#{loc}://#{directory.identity}/#{path}"
      end

    end

    extend ObjectStorage

  end
end
