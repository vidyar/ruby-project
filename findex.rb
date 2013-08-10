require 'digest/md5'
require 'yaml'

require 'fmatch'
require 'fmeta'

include FileMatch


DBFILE = "fmetadata.db"


if ARGV.size != 1
    $stderr << "usage: findex <PATH>\n"
    exit 0
end


puts "Loading DB #{DBFILE} ..."
t0 = Time.now
h = {}
needupdate = true
if File.exists?(DBFILE)
    obj = YAML::load(File.read(DBFILE))
    if obj.is_a?(Hash)
        h = obj
        needupdate = false
    end
end
t1 = Time.now
puts "Loaded DB in #{(t1-t0).round(2)}s."

indexpath = ARGV[0]
puts "Indexing #{indexpath} ..."
t0 = Time.now

for fpath in Dir.glob("#{indexpath}/**/*", File::FNM_DOTMATCH).select { |e| File.ftype(e) == "file" && has_folder?(".git", e.force_encoding("binary")) == false }
    begin
        fpath = File.realpath(fpath).force_encoding("binary")
        fsize = File.size(fpath)

        if fsize == 0
            puts "[SKIP]: #{fpath}"
            next
        end

        # Lazy index the file.
        if h[fsize].nil?
            h[fsize] = fpath
            needupdate = true
            puts "[NEW]: #{fpath} nil"
        else
            if h[fsize].is_a?(String)
                p = h[fsize]
                if p == fpath
                    puts "[DUP]: #{fpath}"
                    puts "       #{p}"
                    next
                end

                d = Digest::MD5.hexdigest(File.read(p))
                h[fsize] = { d => FileMeta.new(fsize, p, d) }
                needupdate = true
            end
            digest = Digest::MD5.hexdigest(File.read(fpath))
            if h[fsize][digest].nil?
                h[fsize][digest] = FileMeta.new(fsize, fpath, digest)
                needupdate = true
                puts "[NEW]: #{fpath} #{digest}"
            else
                puts "[DUP]: #{fpath}"
                puts "       #{h[fsize][digest].path}"
            end
        end
    rescue StandardError => e
        puts "[FAIL]: file=\"#{fpath}\" #{e.message}"
    end
end
t1 = Time.now
puts "Indexing completed in #{(t1-t0).round(2)}s."

if needupdate
    puts "Updating DB #{DBFILE} ..."
    t0 = Time.now
    File.write(DBFILE, YAML::dump(h))
    t1 = Time.now
    puts "Updated DB in #{(t1-t0).round(2)}s."
else
    puts "Skip updating DB."
end
