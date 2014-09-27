SimpleCov.start do
  add_filter do |src|
    src.filename =~ /^#{Regexp.escape(File.dirname(__FILE__))}\/spec/
  end
end
