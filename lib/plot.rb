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


def gnuplot(title, keys, values)

    png = "resources/#{dummy_name}.png"
    axis = if values[0]['epoch'] then 'epoch' else 'iteration' end

    values = values.select {|item|
        ok = true
        for k in keys
            ok = false if item[k] == nil
        end
        ok
    }

    fsize = [3, (values.size / 100).to_i].max
    values = smooth(keys, values, fsize)

    dat = Tempfile.open('dat') {|fp|
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

    gp = Tempfile.open('gp') {|fp|

        fp.print """
set title '#{title} (#{png})'
set terminal pngcairo size 800,500
set output '#{png}'
set grid
set xlabel '#{axis}'
plot '#{dat.path}' u 1:2 smooth unique title '#{keys[0]}'"""

        for i in 1...keys.size
            fp.print ", '' u 1:#{i+2} smooth unique title '#{keys[i]}'"
        end
        fp
    }

    `gnuplot #{gp.path}`
    return png
end


def plot(path, axis_type, data_type)

    p path
    dat = JSON.load(open(path).read)
    keys = Set.new
    values = []

    for d in dat

        item = {}
        item[axis_type] = d[axis_type]

        for key, val in d
            next if key == 'epoch'
            next if key == 'iteration'

            if data_type == 'main' and key.start_with? 'main/'
                k = key.sub(/^main./, '')
                keys << k
                item[k] = val
            end

            if data_type == 'validation' and key.start_with? 'validation/main/'
                k = key.sub(/^validation.main./, '')
                keys << k
                item[k] = val
            end
        end
        values << item
    end

    keys = keys.to_a.sort
    png = gnuplot data_type, keys, values
    return png
end
