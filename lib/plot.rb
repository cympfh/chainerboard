require 'json'
require 'set'
require 'tempfile'
require 'time'
require "#{__dir__}/color.rb"

def dummy_name
  "#{Time.now.to_i}.#{rand(1000)}"
end

# smoothing
class Filter
  def initialize(fsize)
    @fsize = fsize
    @hist = []
  end

  def add(x)
    @hist << x
    @hist = @hist[-@fsize..-1] if @hist.size > @fsize
  end

  def value
    @hist.inject(:+) / @hist.size
  end
end

def smooth(keys, values, fsize)
  axis = values[0]['epoch'] ? 'epoch' : 'iteration'

  filters = {}
  keys.each { |k| filters[k] = Filter.new(fsize) }

  values2 = []

  values.each do |item|
    item2 = { axis => item[axis] }
    keys.each do |k|
      filters[k].add(item[k])
      item2[k] = filters[k].value
    end
    values2 << item2
  end

  values2
end

def write(axis, keys, values)
  Tempfile.open('dat') do |fp|
    body = values.map do |item|
      column = [item[axis]]
      keys.each { |k| column << item[k] }
      column.join(' ')
    end.join("\n")
    fp.puts body
    fp
  end
end

def gnuplot_template(png, axis, opt)
  body = <<EOS
set title '(#{png})'
set terminal pngcairo size 800,500
set output '#{png}'
set grid
set key right outside
set xlabel '#{axis}'
EOS

  body += "set xrange[#{opt[:xrange] || '0:'}]\n"
  body += "set yrange[#{opt[:yrange]}]\n" if opt[:yrange]
  body += "set xtics #{opt[:xtics]}\n" if opt[:xtics]
  body += "set ytics #{opt[:ytics]}\n" if opt[:ytics]

  body
end

def gnuplot_body(keys, path_m, path_v)
  plots = []
  keys[:main].each_with_index do |key, i|
    cl = Color.get key
    puts "main/#{key} #{cl}"
    plots << "'#{path_m}' u 1:#{i + 2} dt '_-' lc rgb '#{cl}' lw 1 smooth unique title 'train/#{key}'"
  end

  keys[:validation].each_with_index do |key, i|
    cl = Color.get key
    puts "val/#{key} #{cl}"
    plots << "'#{path_v}' u 1:#{i + 2} lc rgb '#{cl}' lw 1 smooth unique title 'test/#{key}'"
  end

  "plot #{plots.join(', ')}"
end

def gnuplot(axis, keys, values, opt)
  png = "/tmp/#{dummy_name}.png"

  [:main, :validation].each do |m|
    values[m] = values[m].select { |item| keys[m].all? { |k| item[k] } }
    fsize = [3, (values[m].size / 50).to_i].max
    values[m] = smooth(keys[m], values[m], fsize)
  end

  dat_m = write(axis, keys[:main], values[:main])
  dat_v = write(axis, keys[:validation], values[:validation])

  gp = Tempfile.open('gp') do |fp|
    fp.puts gnuplot_template(png, axis, opt)
    fp.puts gnuplot_body(keys, dat_m.path, dat_v.path)
    fp
  end

  `gnuplot #{gp.path}`
  png
end

def plot(path, axis, opt)
  dat = JSON.load open(path).read
  keys = { main: Set.new, validation: Set.new }
  values = { main: [], validation: [] }

  dat.each do |d|
    item_m = {}
    item_v = {}
    item_m[axis] = d[axis]
    item_v[axis] = d[axis]

    d.each do |key, val|
      next if key == 'epoch'
      next if key == 'iteration'

      if key.start_with? 'main/'
        k = key.sub(/^main./, '')
        keys[:main] << k
        item_m[k] = val
      end

      if key.start_with? 'validation/main/'
        k = key.sub(/^validation.main./, '')
        keys[:validation] << k
        item_v[k] = val
      end
    end
    values[:main] << item_m
    values[:validation] << item_v
  end

  keys[:main] = keys[:main].to_a.sort
  keys[:validation] = keys[:validation].to_a.sort
  png = gnuplot axis, keys, values, opt
  png
end
