require 'digest'

class Entry
  attr_reader :path, :entries
  def initialize(path)
    @path = path
    @entries = []
  end

  def name
    out = "#{File.basename(path)}"
  end

  def format
    s, cont, skip = yield self
    if (!skip)
      return nil
    end
    return s
  end

  def build(ignore: [], depth: 1000)
  end
end

class FileEntry < Entry
  attr_accessor :size
  def initialize(dir)
    super(dir)
    @size = File.size(path)
  end

  def key
    base = File.basename(path)
    return "#{base}_#{File.size(path)}"
  end
end

class DirectoryEntry < Entry
  attr_accessor :entries, :size

  def initialize(dir)
    super(dir)
    @entries = []
    @size = 0
  end

  def key
    str = entries.map{ |e| e.key }.join("_")
    Digest::MD5.hexdigest(str)
  end

  def build(ignore: [], depth: 1000)
    b = File.basename(path)
    if (ignore.include?(b))
      STDERR.puts "skipping #{path}"
      return
    end
    STDERR.puts "building #{path}"

    Dir["#{path}/*"].each do |f|
      if (!File.directory?(f))
        @entries << FileEntry.new(f)
      else
        @entries << DirectoryEntry.new(f)
      end
    end

    @entries.each do |e|
      e.build(ignore: ignore, depth: depth-1)
      @size += e.size
    end
  end

  def format(&block)
    out, cont, show = yield self
    if (!show)
      return nil
    end

    if (cont)
      @entries.each do |e|
        pre = e.format(&block)
        if (pre)
          s = pre.gsub("\n", "\n| ")
          out +=  "\n|-> " + s
        end
      end
    end

    return out
  end

  def to_s
    format { |e| e.name }
  end
end

class Repository
  attr_reader :contents

  class Entry
    attr_accessor :duplicates

    def initialize(e)
      @duplicates = [ e ]
    end

    def aggregate(e)
      @duplicates << e
    end
  end

  def initialize(tl)
    @contents = { }
    scan(tl)
  end

  def stats(obj)
    entry = contents[obj.key]
    total_size = obj.size
    dup_pct = "0"
    if (total_size != 0)
      dup_pct = ((duplicated_size(obj).to_f / total_size) * 100).round
    end
    extra = "#{obj.size} bytes, duplication #{dup_pct}% #{obj.key}"
    if (entry.duplicates.length == 1)
      return "unique, #{extra}", true
    end
    return "#{entry.duplicates.length} duplicates, #{extra}", false
  end

  def duplicated_size(obj)
    total = 0
    if (obj.entries.length > 0)
      total += obj.entries.map { |e| duplicated_size(e) }.inject{ |sum,x| sum + x }
    else
      entry = contents[obj.key]
      if (entry.duplicates.length != 1)
        total += obj.size
      end
    end
    return total
  end

  def scan(obj)
    k = obj.key
    if (contents.include?(k))
      contents[k].aggregate(obj)
    else
      contents[k] = Entry.new(obj)
    end

    obj.entries.each do |e|
      scan(e)
    end
  end
end

dir = ARGV[0]
results = {}
dir_results = {}

d = DirectoryEntry.new(dir)
d.build()
STDERR.puts "Visit complete"

r = Repository.new(d)

s = d.format do |e|
  STDERR.puts "Formatting #{e.path}"
  s, unique = r.stats(e)
  next "#{e.name} (#{s})", unique, e.kind_of?(DirectoryEntry)
end
puts s

=begin
scan(dir, results, dir_results, depth: 10)
def scan(dir, results, dir_results, depth: 100)
  files = Dir["#{dir}/*"]
  raise "Already scanned #{dir}" if dir_results.include?(dir)
  dir_result = DirResults.new()
  dir_results[dir] = dir_result
  files.each do |f|
    if (!File.directory?(f))
      size = File.size(f)
      key = key_for(f, size)
      if (results.include?(key))
        results[key] << f
        dir_result.duplicates += 1
      else
        results[key] = [ f ]
        dir_result.unique += 1
      end
    elsif (depth > 0)
      scan(f, results, depth: depth-1)
    else
      puts "Skipping #{f}"
    end
  end
end

unique_file = File.open('unique.txt', 'w')
duplicate_file = File.open('duplicates.txt', 'w')

unique = []
unique_size = 0
duplicates = []
duplicated_size = 0
results.each do |k, v|
  unique << v[0]
  unique_size += File.size(v[0])
  if (v.length == 1)
    unique_file.write("#{v[0]}\n")
  end

  if (v.length > 1)
    duplicates << v[0]
    duplicated_size += File.size(v[0]) * (v.length-1)

    duplicate_file.write("-----\n")
    v.each do |f|
      duplicate_file.write("#{f}\n")
    end
  end
end

puts "#{unique.length} unique files, #{unique_size} bytes"
puts "#{duplicates.length} duplicated files, #{duplicated_size} bytes"

dir_results.each do |path, data|
  if (data.unique == 0)
    puts "#{path} contains 0 unqiue entries"
  end
end

=end
