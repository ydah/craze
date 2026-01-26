# frozen_string_literal: true

require 'test_helper'

class HelpersTest < Minitest::Test
  def setup
    @context = Craze::Template::Context.new(
      site: { 'base_path' => '/', 'title' => 'Test Site' },
      page: { 'title' => 'Test Page', 'content' => '<p>Hello</p>' }
    )
  end

  def test_url_for_with_default_base
    assert_equal '/about', @context.url_for('/about')
    assert_equal '/posts/hello/', @context.url_for('posts/hello/')
  end

  def test_url_for_with_custom_base
    context = Craze::Template::Context.new(
      site: { 'base_path' => '/blog' },
      page: {}
    )

    assert_equal '/blog/about', context.url_for('/about')
  end

  def test_asset_path
    assert_equal '/assets/style.css', @context.asset_path('style.css')
  end

  def test_escape_html
    assert_equal '&lt;script&gt;', @context.escape_html('<script>')
    assert_equal 'Hello &amp; World', @context.escape_html('Hello & World')
  end

  def test_format_date_with_date
    date = Date.new(2026, 1, 15)

    assert_equal '2026-01-15', @context.format_date(date)
    assert_equal 'January 15, 2026', @context.format_date(date, '%B %d, %Y')
  end

  def test_format_date_with_string
    assert_equal '2026-01-15', @context.format_date('2026-01-15')
  end

  def test_format_date_with_nil
    assert_equal '', @context.format_date(nil)
  end

  def test_vite_client_tag_in_development
    context = Craze::Template::Context.new(
      site: {
        'frontend' => {
          'mode' => 'vite',
          'dev_server' => { 'url' => 'http://localhost:5173' }
        }
      },
      page: {},
      environment: 'development'
    )

    assert_includes context.vite_client_tag, 'http://localhost:5173/@vite/client'
  end

  def test_vite_client_tag_in_production
    context = Craze::Template::Context.new(
      site: { 'frontend' => { 'mode' => 'vite' } },
      page: {},
      environment: 'production'
    )

    assert_empty context.vite_client_tag
  end

  def test_vite_js_tag_in_development
    context = Craze::Template::Context.new(
      site: {
        'frontend' => {
          'mode' => 'vite',
          'dev_server' => { 'url' => 'http://localhost:5173' }
        }
      },
      page: {},
      environment: 'development'
    )

    assert_includes context.vite_js_tag('src/main.ts'), 'http://localhost:5173/src/main.ts'
  end

  def test_vite_js_tag_in_production_with_manifest
    manifest = { 'src/main.ts' => { 'file' => 'assets/main-abc123.js' } }
    context = Craze::Template::Context.new(
      site: { 'frontend' => { 'mode' => 'vite' } },
      page: {},
      environment: 'production',
      vite_manifest: manifest
    )

    assert_includes context.vite_js_tag('src/main.ts'), '/assets/main-abc123.js'
    refute_includes context.vite_js_tag('src/main.ts'), '/assets/assets/'
  end

  def test_vite_css_tag_in_development
    context = Craze::Template::Context.new(
      site: {
        'frontend' => {
          'mode' => 'vite',
          'dev_server' => { 'url' => 'http://localhost:5173' }
        }
      },
      page: {},
      environment: 'development'
    )

    assert_empty context.vite_css_tag('src/main.ts')
  end

  def test_vite_css_tag_in_production_with_manifest
    manifest = {
      'src/main.ts' => {
        'file' => 'assets/main-abc123.js',
        'css' => ['assets/main-abc123.css', 'assets/vendor-def456.css']
      }
    }
    context = Craze::Template::Context.new(
      site: { 'frontend' => { 'mode' => 'vite' } },
      page: {},
      environment: 'production',
      vite_manifest: manifest
    )

    result = context.vite_css_tag('src/main.ts')
    assert_includes result, '/assets/main-abc123.css'
    assert_includes result, '/assets/vendor-def456.css'
    refute_includes result, '/assets/assets/'
  end

  def test_vite_css_tag_in_production_without_css
    manifest = { 'src/main.ts' => { 'file' => 'assets/main-abc123.js' } }
    context = Craze::Template::Context.new(
      site: { 'frontend' => { 'mode' => 'vite' } },
      page: {},
      environment: 'production',
      vite_manifest: manifest
    )

    assert_empty context.vite_css_tag('src/main.ts')
  end

  def test_vite_js_tag_raises_when_entry_not_in_manifest
    manifest = {}
    context = Craze::Template::Context.new(
      site: { 'frontend' => { 'mode' => 'vite' } },
      page: {},
      environment: 'production',
      vite_manifest: manifest
    )

    assert_raises(RuntimeError) { context.vite_js_tag('src/missing.ts') }
  end
end
