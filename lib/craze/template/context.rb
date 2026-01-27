# frozen_string_literal: true

require 'erb'
require_relative 'helpers'

module Craze
  module Template
    class Context
      include Helpers

      attr_reader :site, :page, :collections, :data, :templates_dir

      def initialize(**options)
        @site = options[:site]
        @page = options[:page]
        @collections = options[:collections] || {}
        @data = options[:data] || {}
        @environment = options[:environment] || 'production'
        @vite_manifest = options[:vite_manifest]
        @templates_dir = options[:templates_dir]
      end

      def render_binding
        binding
      end
    end
  end
end
