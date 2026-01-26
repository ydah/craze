# frozen_string_literal: true

require 'cgi/escape'

module Craze
  module Template
    module Helpers
      def url_for(path)
        base_path = @site&.dig('base_path') || '/'
        path = "/#{path}" unless path.start_with?('/')
        path = "#{base_path.chomp('/')}#{path}" unless base_path == '/'
        path
      end

      def asset_path(name)
        url_for("/assets/#{name}")
      end

      def escape_html(text)
        CGI.escapeHTML(text.to_s)
      end

      def format_date(date, format = '%Y-%m-%d')
        return '' if date.nil?

        date = Date.parse(date.to_s) unless date.is_a?(Date) || date.is_a?(Time)
        date.strftime(format)
      end

      def vite_client_tag
        return '' unless vite_dev_mode?

        dev_url = @site&.dig('frontend', 'dev_server', 'url') || 'http://localhost:5173'
        %(<script type="module" src="#{dev_url}/@vite/client"></script>)
      end

      def vite_js_tag(entry)
        if vite_dev_mode?
          dev_url = @site&.dig('frontend', 'dev_server', 'url') || 'http://localhost:5173'
          %(<script type="module" src="#{dev_url}/#{entry}"></script>)
        else
          manifest_entry = vite_manifest_entry(entry)
          raise "Entry #{entry.inspect} not found in Vite manifest" unless manifest_entry

          %(<script type="module" src="#{vite_output_url(manifest_entry['file'])}"></script>)
        end
      end

      def vite_css_tag(entry)
        if vite_dev_mode?
          ''
        else
          manifest_entry = vite_manifest_entry(entry)
          raise "Entry #{entry.inspect} not found in Vite manifest" unless manifest_entry

          css_files = manifest_entry['css'] || []
          css_files.map { |css| %(<link rel="stylesheet" href="#{vite_output_url(css)}">) }.join("\n")
        end
      end

      def vite_asset_path(entry)
        if vite_dev_mode?
          dev_url = @site&.dig('frontend', 'dev_server', 'url') || 'http://localhost:5173'
          "#{dev_url}/#{entry}"
        else
          manifest_entry = vite_manifest_entry(entry)
          raise "Entry #{entry.inspect} not found in Vite manifest" unless manifest_entry

          vite_output_url(manifest_entry['file'])
        end
      end

      private

      def vite_dev_mode?
        @environment == 'development' && @site&.dig('frontend', 'mode') == 'vite'
      end

      def vite_manifest_entry(entry)
        return nil unless @vite_manifest

        @vite_manifest[entry]
      end

      def vite_output_url(manifest_path)
        public_base = @site&.dig('frontend', 'build', 'public_base') || ''
        base = public_base.chomp('/')
        path = manifest_path.sub(%r{^/}, '')
        url_for("#{base}/#{path}")
      end
    end
  end
end
