# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative 'config'
require_relative 'site_graph/builder'
require_relative 'template/renderer'
require_relative 'integrations'

module Craze
  class Pipeline
    EVENTS = %i[
      before_build
      after_discover
      after_parse
      after_render
      before_write
      after_write
      build_failed
    ].freeze

    def initialize(config_path: 'craze.yml', environment: 'production')
      @config = Config.new(config_path, environment: environment)
      @environment = environment
      @listeners = Hash.new { |h, k| h[k] = [] }
      @pages = []
      @collections = {}
    end

    def on(event, &block)
      raise ArgumentError, "Unknown event: #{event}" unless EVENTS.include?(event)

      @listeners[event] << block
    end

    def build
      emit(:before_build)

      discover_and_parse
      emit(:after_discover)
      emit(:after_parse)

      render_pages
      emit(:after_render)

      emit(:before_write)
      write_output
      run_integrations
      emit(:after_write)

      build_summary
    rescue StandardError => e
      emit(:build_failed, e)
      raise
    end

    private

    def emit(event, *args)
      @listeners[event].each { |block| block.call(*args) }
    end

    def discover_and_parse
      builder = SiteGraph::Builder.new(@config.to_h)
      result = builder.build

      @pages = result[:pages]
      @collections = result[:collections]
    end

    def render_pages
      templates_dir = @config.dig('templates', 'dir') || 'templates'
      renderer = Template::Renderer.new(
        templates_dir: templates_dir,
        site: site_data,
        environment: @environment,
        vite_manifest: load_vite_manifest
      )

      collections_data = @collections.transform_values(&:to_a)

      @rendered_pages = @pages.map do |page|
        html = renderer.render(page, collections: collections_data)
        { page: page, html: html }
      end
    end

    def write_output
      out_dir = @config.dig('build', 'out_dir') || 'dist'

      FileUtils.rm_rf(out_dir) if @config.dig('build', 'clean')

      @rendered_pages.each do |entry|
        relative_output = entry[:page].output_path.sub(%r{^/}, '')
        output_path = File.join(out_dir, relative_output)
        FileUtils.mkdir_p(File.dirname(output_path))
        File.write(output_path, entry[:html])
      end

      copy_assets(out_dir)
    end

    def run_integrations
      integration_names = @config['integrations'] || []
      out_dir = @config.dig('build', 'out_dir') || 'dist'

      integration_names.each do |name|
        integration_class = Integrations.load(name)
        next unless integration_class

        integration = integration_class.new(
          config: @config.to_h,
          pages: @pages,
          collections: @collections,
          out_dir: out_dir
        )
        integration.run
      end
    end

    def copy_assets(out_dir)
      assets_dir = @config.dig('assets', 'dir') || 'assets'
      return unless Dir.exist?(assets_dir)

      dest = File.join(out_dir, 'assets')
      FileUtils.mkdir_p(dest)
      FileUtils.cp_r(Dir.glob("#{assets_dir}/*"), dest)
    end

    def site_data
      site = @config['site']&.dup || {}
      site['base_path'] = @config.dig('build', 'base_path') || '/'
      site['frontend'] = @config['frontend'] if @config['frontend']
      site
    end

    def load_vite_manifest
      return nil unless @environment == 'production'
      return nil unless @config.dig('frontend', 'mode') == 'vite'

      manifest_path = @config.dig('frontend', 'manifest', 'path')
      raise 'frontend.manifest.path is not set for Vite production build' unless manifest_path

      unless File.exist?(manifest_path)
        raise "Vite manifest not found at #{manifest_path.inspect}. Run the Vite build before building the site."
      end

      JSON.parse(File.read(manifest_path))
    end

    def build_summary
      {
        pages: @rendered_pages.size,
        collections: @collections.keys,
        output_dir: @config.dig('build', 'out_dir') || 'dist'
      }
    end
  end
end
