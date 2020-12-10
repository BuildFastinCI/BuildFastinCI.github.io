def files_at_commit(sha, filter = lambda { true })

    begin
        checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository',info[1]+'@'+info[2]),File.dirname(__FILE__)) 
        git = Rugged::Repository.new(checkout_dir)
        files = lslr(git.lookup(sha).tree)
      if files.size <= 0
        log "No files for commit #{sha}"
      end
      files.select { |x| filter.call(x) }
    rescue StandardError => e
      log "Cannot find commit #{sha} in base repo"
      []
    end
end

def lslr(tree, path = '')
    all_files = []
    for f in tree.map { |x| x }
      f[:path] = path + '/' + f[:name]
      if f[:type] == :tree
        begin
          all_files << lslr(git.lookup(f[:oid]), f[:path])
        rescue StandardError => e
          log e
          all_files
        end
      else
        all_files << f
      end
    end
    all_files.flatten
end

sloc = src_lines(build[:commit])
def src_files(sha)
    files_at_commit(sha, src_file_filter)
end
def src_lines(sha)
    count_lines(src_files(sha))
end
def count_lines(files, include_filter = lambda { |x| true })
    files.map { |f|
      stripped(f).lines.select { |x|
        not x.strip.empty?
      }.select { |x|
        include_filter.call(x)
      }.size
    }.reduce(0) { |acc, x| acc + x }
end
