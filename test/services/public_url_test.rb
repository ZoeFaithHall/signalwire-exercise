require "test_helper"
require "tempfile"

class PublicUrlTest < ActiveSupport::TestCase
  setup do
    @saved = ENV.to_h.slice("PUBLIC_URL", "CLOUDFLARED_LOG")
    ENV.delete("PUBLIC_URL")
    ENV.delete("CLOUDFLARED_LOG")
  end

  teardown do
    %w[PUBLIC_URL CLOUDFLARED_LOG].each { |k| ENV.delete(k) }
    @saved.each { |k, v| ENV[k] = v }
  end

  test "prefers PUBLIC_URL and strips a trailing slash" do
    ENV["PUBLIC_URL"] = "https://voice.example.com/"
    assert_equal "https://voice.example.com", PublicUrl.current
  end

  test "reads the most recent trycloudflare URL from the log" do
    file = Tempfile.new("cloudflared.log")
    file.write("boot https://aaa-bbb.trycloudflare.com first\n")
    file.write("restart https://ccc-ddd.trycloudflare.com latest\n")
    file.flush
    ENV["CLOUDFLARED_LOG"] = file.path

    assert_equal "https://ccc-ddd.trycloudflare.com", PublicUrl.current
  ensure
    file.close!
  end

  test "returns nil when no URL is available anywhere" do
    ENV["CLOUDFLARED_LOG"] = "/nonexistent/cloudflared.log"
    assert_nil PublicUrl.current
  end
end
