#!/usr/bin/env ruby
# frozen_string_literal: true

# Live SEO + LLM discoverability verifier (stdlib only).
#
# Usage:
#   ruby verify_seo.rb https://example.com
#   SITE=https://example.com ruby verify_seo.rb
#
# Customize PROBES below for your site, or pass a JSON config path:
#   ruby verify_seo.rb https://example.com ./seo-probes.json
#
# References:
#   https://evilmartians.com/chronicles/how-to-make-your-website-visible-to-llms
#   https://ruby.evilmartians.com/
#   https://evilmartians.com/skills/llms-visibility.md

require "json"
require "net/http"
require "openssl"
require "uri"

class VerifySeo
  Result = Data.define(:name, :status, :detail) # :pass, :warn, :fail

  AI_BOTS = %w[GPTBot ClaudeBot PerplexityBot CCBot Google-Extended].freeze

  DEFAULT_PROBES = {
    "sample_html_paths" => ["/", "/guide/introduction/"],
    "sample_md_paths" => ["/index.md", "/guide/introduction.md"],
    "section_indexes" => [
      { "html" => "/guide/", "md" => "/guide.md" },
      { "html" => "/blog/", "md" => "/blog.md" }
    ],
    "require_llms_full" => true,
    "require_feed" => false,
    "require_json_ld" => true,
    "require_markdown_negotiation" => true
  }.freeze

  def initialize(base_url, config_path: nil)
    @base = normalize_base(base_url)
    @config = DEFAULT_PROBES.merge(load_config(config_path))
    @results = []
  end

  def run
    check_robots
    check_sitemap
    check_llms_txt
    check_llms_full if @config["require_llms_full"]
    check_feed if @config["require_feed"]

    @config["sample_md_paths"].each { |path| check_md_mirror(path) }
    @config["section_indexes"].each { |pair| check_section_index(pair) }

    @config["sample_html_paths"].each { |path| check_html_page(path) }

    print_report
    @results.any? { |r| r.status == :fail } ? 1 : 0
  end

  private

  def normalize_base(url)
    uri = URI.parse(url)
    raise ArgumentError, "URL must be http or https" unless uri.is_a?(URI::HTTP)

    path = uri.path.to_s
    path = "/" if path.empty?
    path = path.sub(%r{/+\z}, "")
    URI("#{uri.scheme}://#{uri.host}#{uri.port && uri.port != uri.default_port ? ":#{uri.port}" : ""}#{path == "" ? "" : path}")
  end

  def load_config(path)
    return {} unless path && File.file?(path)

    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    warn "Config parse error: #{e.message}"
    {}
  end

  def absolute(path)
    path = "/#{path}" unless path.start_with?("/")
    URI.join(@base.to_s + "/", path.sub(%r{\A/}, ""))
  end

  def fetch(uri, headers: {}, method: :get, body: nil, max_redirects: 5)
    current = uri
    redirects = 0

    loop do
      http = Net::HTTP.new(current.host, current.port)
      http.use_ssl = current.scheme == "https"
      http.open_timeout = 15
      http.read_timeout = 20
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      klass = method == :head ? Net::HTTP::Head : Net::HTTP::Get
      request = klass.new(current)
      headers.each { |k, v| request[k] = v }
      request.body = body if body

      response = http.request(request)

      if response.is_a?(Net::HTTPRedirection) && redirects < max_redirects
        redirects += 1
        current = URI.join(current, response["location"])
        next
      end

      return {
        uri: current,
        code: response.code.to_i,
        headers: response.each_header.to_h,
        body: response.body.to_s
      }
    end
  end

  def pass(name, detail = "ok")
    @results << Result.new(name:, status: :pass, detail:)
  end

  def warn(name, detail)
    @results << Result.new(name:, status: :warn, detail:)
  end

  def fail(name, detail)
    @results << Result.new(name:, status: :fail, detail:)
  end

  def check_robots
    res = fetch(absolute("/robots.txt"))
    unless res[:code] == 200
      fail("robots.txt", "HTTP #{res[:code]}")
      return
    end

    body = res[:body]
    pass("robots.txt", "HTTP 200")

    if body.match?(/Sitemap:\s*\S+/i)
      pass("robots.txt sitemap directive", "present")
    else
      warn("robots.txt sitemap directive", "missing Sitemap: line")
    end

    if body.match?(/Content-Signal:/i)
      pass("robots.txt Content-Signal", "present")
    else
      warn("robots.txt Content-Signal", "missing (recommended for AI crawlers)")
    end

    AI_BOTS.each do |bot|
      if body.match?(/User-agent:\s*#{Regexp.escape(bot)}[\s\S]*?Disallow:\s*\/\s*$/im)
        fail("robots.txt #{bot}", "Disallow: /")
      else
        pass("robots.txt #{bot}", "not blocked")
      end
    end
  rescue StandardError => e
    fail("robots.txt", e.message)
  end

  def check_sitemap
    res = fetch(absolute("/sitemap.xml"))
    if res[:code] == 200 && res[:body].include?("<urlset")
      pass("sitemap.xml", "valid XML urlset")
    else
      fail("sitemap.xml", "HTTP #{res[:code]} or invalid XML")
    end
  rescue StandardError => e
    fail("sitemap.xml", e.message)
  end

  def check_llms_txt
    res = fetch(absolute("/llms.txt"))
    body = res[:body].to_s
    if res[:code] == 200 && body.start_with?("#")
      pass("llms.txt", "HTTP 200, Markdown H1")
    else
      fail("llms.txt", "HTTP #{res[:code]} or missing H1")
    end
  rescue StandardError => e
    fail("llms.txt", e.message)
  end

  def check_llms_full
    res = fetch(absolute("/llms-full.txt"))
    if res[:code] == 200 && res[:body].to_s.length > 500
      pass("llms-full.txt", "HTTP 200, #{res[:body].length} bytes")
    else
      warn("llms-full.txt", "HTTP #{res[:code]} or very short body")
    end
  rescue StandardError => e
    warn("llms-full.txt", e.message)
  end

  def check_feed
    res = fetch(absolute("/feed.xml"))
    if res[:code] == 200 && res[:body].include?("<feed")
      pass("feed.xml", "Atom/RSS present")
    else
      warn("feed.xml", "HTTP #{res[:code]} or not Atom")
    end
  rescue StandardError => e
    warn("feed.xml", e.message)
  end

  def check_md_mirror(path)
    res = fetch(absolute(path))
    body = res[:body].to_s
    if res[:code] == 200 && !body.strip.empty? && !body.lstrip.start_with?("<!")
      ct = res[:headers]["content-type"].to_s
      detail = ct.include?("markdown") ? "text/markdown" : "body looks like Markdown"
      pass("MD mirror #{path}", detail)
    else
      fail("MD mirror #{path}", "HTTP #{res[:code]} or HTML response")
    end

    link = res[:headers]["link"].to_s
    if link.match?(/rel=.alternate.*text\/html/i)
      pass("MD Link header #{path}", "points to HTML")
    else
      warn("MD Link header #{path}", "missing rel=alternate type=text/html")
    end
  rescue StandardError => e
    fail("MD mirror #{path}", e.message)
  end

  def check_section_index(pair)
    html_path = pair["html"]
    md_path = pair["md"]
    check_md_mirror(md_path)
    check_html_page(html_path, expected_md: md_path)
  end

  def check_html_page(path, expected_md: nil)
    res = fetch(absolute(path))
    unless res[:code] == 200
      fail("HTML #{path}", "HTTP #{res[:code]}")
      return
    end

    body = res[:body].to_s
    pass("HTML #{path}", "HTTP 200")

    titles = body.scan(/<title[^>]*>/i).length
    if titles == 1
      pass("HTML #{path} single title", "ok")
    else
      fail("HTML #{path} title count", "found #{titles}, want 1")
    end

    descriptions = body.scan(/<meta[^>]+name=["']description["']/i).length
    if descriptions == 1
      pass("HTML #{path} meta description", "ok")
    else
      fail("HTML #{path} meta description", "found #{descriptions}, want 1")
    end

    if body.match?(/<link[^>]+rel=["']canonical["']/i)
      pass("HTML #{path} canonical", "present")
    else
      warn("HTML #{path} canonical", "missing")
    end

    %w[og:title og:description og:image].each do |prop|
      if body.match?(/property=["']#{Regexp.escape(prop)}["']/i)
        pass("HTML #{path} #{prop}", "present")
      else
        warn("HTML #{path} #{prop}", "missing")
      end
    end

    if @config["require_json_ld"]
      if body.include?("application/ld+json") && body.include?("schema.org")
        pass("HTML #{path} JSON-LD", "present")
      else
        fail("HTML #{path} JSON-LD", "missing application/ld+json or schema.org @context")
      end
    end

    md_path = expected_md || html_path_to_md(path)
    if body.match?(/rel=["']alternate["'][^>]+type=["']text\/markdown["']/i) ||
       body.match?(/type=["']text\/markdown["'][^>]+rel=["']alternate["']/i)
      pass("HTML #{path} link alternate markdown", "present")
    else
      fail("HTML #{path} link alternate markdown", "missing")
    end

    if body.match?(/visually-hidden/i) && body.match?(/Markdown version of this page/i)
      pass("HTML #{path} LLM pointer", "visually-hidden div")
    else
      warn("HTML #{path} LLM pointer", "missing visually-hidden Markdown hint")
    end

    link_header = res[:headers]["link"].to_s
    if link_header.match?(/rel=.alternate.*text\/markdown/i)
      pass("HTML #{path} Link header", "markdown alternate")
    else
      warn("HTML #{path} Link header", "missing Link: ... text/markdown")
    end

    if @config["require_markdown_negotiation"]
      check_markdown_negotiation(path, md_path)
    end
  rescue StandardError => e
    fail("HTML #{path}", e.message)
  end

  def check_markdown_negotiation(html_path, md_path)
    res = fetch(absolute(html_path), headers: { "Accept" => "text/markdown, text/html;q=0.5" })
    body = res[:body].to_s.strip
    vary = res[:headers]["vary"].to_s.downcase

    if res[:code] == 200 && !body.start_with?("<!") && !body.start_with?("<html")
      if vary.include?("accept")
        pass("Negotiation #{html_path}", "Markdown body + Vary: Accept")
      else
        warn("Negotiation #{html_path}", "Markdown body but missing Vary: Accept")
      end
    elsif res[:code] == 406
      warn("Negotiation #{html_path}", "406 (check Accept rules)")
    else
      warn(
        "Negotiation #{html_path}",
        "still HTML or HTTP #{res[:code]} (edge function / server may be missing; direct #{md_path} still works)"
      )
    end
  rescue StandardError => e
    warn("Negotiation #{html_path}", e.message)
  end

  def html_path_to_md(path)
    normalized = path.sub(%r{/index\.html\z}, "").sub(%r{/+\z}, "")
    normalized = "/" if normalized.empty?
    return "/index.md" if normalized == "/"
    return "/guide.md" if normalized == "/guide"
    return "/blog.md" if normalized == "/blog"

    "#{normalized}.md"
  end

  def print_report
    puts
    puts "SEO + LLM discoverability report"
    puts "Site: #{@base}"
    puts "-" * 60

    grouped = { pass: [], warn: [], fail: [] }
    @results.each { |r| grouped[r.status] << r }

    grouped[:fail].each { |r| puts "FAIL  #{r.name} — #{r.detail}" }
    grouped[:warn].each { |r| puts "WARN  #{r.name} — #{r.detail}" }
    grouped[:pass].each { |r| puts "PASS  #{r.name} — #{r.detail}" }

    puts "-" * 60
    puts "Pass: #{grouped[:pass].length}  Warn: #{grouped[:warn].length}  Fail: #{grouped[:fail].length}"
    puts
    puts "Optional external scanners:"
    puts "  https://acceptmarkdown.com"
    puts "  https://isitagentready.com"
    puts "  https://ruby.evilmartians.com/"
  end
end

if __FILE__ == $PROGRAM_NAME
  base = ARGV.find { |a| a.match?(%r{\Ahttps?://}) } || ENV["SITE"]
  abort "Usage: ruby verify_seo.rb https://example.com [config.json]" unless base

  config_path = ARGV.find { |a| a.end_with?(".json") }
  exit VerifySeo.new(base, config_path: config_path).run
end
