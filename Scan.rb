def key_for(filepath, size)
  base = File.basename(filepath)
  return "#{base}_#{size}"
end

def scan(dir, results, depth: 100)
  files = Dir["#{dir}/*"]
  files.each do |f|
    if (!File.directory?(f))
      size = File.size(f)
      key = key_for(f, size)
      if (results.include?(key))
        results[key] << f
      else
        results[key] = [ f ]
      end
    elsif (depth > 0)
      scan(f, results, depth: depth-1)
    else
      puts "Skipping #{f}"
    end
  end
end

dir = ARGV[0]
results = {}
scan(dir, results, depth: 2)

puts results
