require 'json'
require 'set'
require 'tempfile'
require 'time'


def dummy_name
    "#{Time.now.to_i}.#{rand(1000)}"
end


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

    axis = if values[0]['epoch'] then 'epoch' else 'iteration' end

    filters = {}
    for k in keys
        filters[k] = Filter.new(fsize)
    end

    values2 = []

    for item in values
        item2 = {}
        item2[axis] = item[axis]
        for k in keys
            filters[k].add(item[k])
            item2[k] = filters[k].value
        end
        values2 << item2
    end

    return values2
end


def write(axis, keys, values)
    Tempfile.open('dat') {|fp|
        body = values.map {|item|
            column = [item[axis]]
            for k in keys
                column << item[k]
            end
            column.join(' ')
        }.join("\n")
        fp.puts body
        fp
    }
end


def gnuplot(axis, keys, values)

    png = "/tmp/#{dummy_name}.png"

    for m in [:main, :validation]
        values[m] = values[m].select{|item|
            keys[m].all? {|k| item[k]}
        }
        fsize = [3, (values[m].size / 100).to_i].max
        values[m] = smooth(keys[m], values[m], fsize)
    end

    dat_m = write(axis, keys[:main], values[:main])
    dat_v = write(axis, keys[:validation], values[:validation])

    gp = Tempfile.open('gp') {|fp|

        fp.puts """
set title '(#{png})'
set terminal pngcairo size 800,500
set output '#{png}'
set grid
set key right outside
set xlabel '#{axis}'
set xrange [0:]
set yrange [0:]
"""

        colors = ["#ff0000", "#00ff00", "#0000ff", "#dddd00", "#00dddd", "#dd00dd"]
        for _ in 0..1000
            colors << "#aaaaaa"
        end

        plots = []
        for i in 0...keys[:main].size
            plots << "'#{dat_m.path}' u 1:#{i+2} dt '_-' lc rgb '#{colors[i]}' lw 1 smooth unique title 'train/#{keys[:main][i]}'"
        end
        for i in 0...keys[:validation].size
            plots << "'#{dat_v.path}' u 1:#{i+2} lc rgb '#{colors[i]}' lw 1 smooth unique title 'test/#{keys[:validation][i]}'"
        end
        fp.print "plot "
        fp.puts plots.join(", ")

        fp
    }

    `gnuplot #{gp.path}`
    return png
end


def plot(path, axis)

    dat = JSON.load(open(path).read)
    keys = {:main => Set.new, :validation => Set.new}
    values = {:main => [], :validation => []}

    for d in dat

        item_m = {}
        item_v = {}
        item_m[axis] = d[axis]
        item_v[axis] = d[axis]

        for key, val in d
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
    png = gnuplot axis, keys, values
    return png
end
