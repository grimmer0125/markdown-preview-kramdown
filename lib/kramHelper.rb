require 'kramdown'

text = ARGV[0]
# puts text
puts Kramdown::Document.new(text).to_html
