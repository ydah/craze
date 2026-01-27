# frozen_string_literal: true

require 'erb'
require_relative 'context'

module Craze
  module Template
    class Renderer
      def initialize(templates_dir:, site: {}, environment: 'production', vite_manifest: nil)
        @templates_dir = templates_dir
        @site = site
        @environment = environment
        @vite_manifest = vite_manifest
      end

      def render(page, collections: {}, data: {})
        context = build_context(page.to_h, collections, data)
        layout_name = page.layout
        layout_path = find_layout(layout_name)

        if layout_path
          template = File.read(layout_path)
          erb = ERB.new(template)
          erb.result(context.render_binding)
        else
          page.html
        end
      end

      def render_string(template_string, page:, collections: {}, data: {})
        context = build_context(page.to_h, collections, data)
        erb = ERB.new(template_string)
        erb.result(context.render_binding)
      end

      private

      def build_context(page_hash, collections, data)
        Context.new(
          site: @site,
          page: page_hash,
          collections: collections,
          data: data,
          environment: @environment,
          vite_manifest: @vite_manifest,
          templates_dir: @templates_dir
        )
      end

      def find_layout(name)
        extensions = %w[.html.erb .erb]
        paths = [
          File.join(@templates_dir, 'layouts', name),
          File.join(@templates_dir, name)
        ]

        paths.each do |base_path|
          extensions.each do |ext|
            full_path = "#{base_path}#{ext}"
            return full_path if File.exist?(full_path)
          end
        end

        nil
      end
    end
  end
end
