#hello.rb

require 'kramdown'

# ARGV.each do|a|
#   puts "Argument: #{a}"
# end

# while STDIN.gets
#   puts $_
# end
#
# while ARGF.gets
#   puts $_
# end

# puts ARGF.read
# puts "aaa"
# text = "binary"
text = ARGV[0]

puts Kramdown::Document.new(text).to_html
