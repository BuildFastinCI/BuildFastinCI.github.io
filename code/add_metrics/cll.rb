require 'rugged'
require_relative 'java_log'

class ExtractGitInfo

  include JavaDatanew

  def initialize(user,repo)
    @user=user
    @repo=repo
    @thread_number=30
    info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
    @first_id=info.now_build_id
    # p @first_id
    last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
    
    @last_id=last_info.now_build_id
    # p @last_id
    checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository',user+'@'+repo),File.dirname(__FILE__))
    # puts checkout_dir
    @git = Rugged::Repository.new(checkout_dir)
  end

  # Recursively get information from all files given a rugged Git tree
  def lslr(tree, path = '')
    all_files = []
    #p tree
    for f in tree.map { |x| x }
      f[:path] = path + '/' + f[:name]
      if f[:type] == :tree
        begin
          all_files << lslr(@git.lookup(f[:oid]), f[:path])
        rescue StandardError => e
          puts $!
          puts $@
          all_files
        end
      else
        all_files << f
      end
    end
    all_files.flatten
  end

  def files_at_commit(sha, filter = lambda { |x| true })
    begin
      files = lslr(@git.lookup(sha).tree)
      if files.size <= 0
        puts "No files for commit #{sha}"
      end
      files.select { |x| filter.call(x) }
    rescue StandardError => e
      puts "Cannot find commit #{sha} in base repo"
      puts $!
      puts $@
      nil
    end
  end

  def stripped(f)
    @stripped ||= Hash.new
    begin
    unless @stripped.has_key? f
      @stripped[f] = strip_comments(@git.read(f[:oid]).data)
    end
    @stripped[f]
    rescue StandardError => e
      @stripped[f]
    end
  end

  def count_lines(files, include_filter = lambda { |x| true })
    return 0 if files.nil?
    files.map { |f|
      stripped(f).lines.select { |x|
        not x.strip.empty?
      }.select { |x|
        include_filter.call(x)
      }.size
    }.reduce(0) { |acc, x| acc + x }
  end

  def src_files(sha)
    files_at_commit(sha, src_file_filter)
  end

  def src_lines(sha)
    count_lines(src_files(sha))
  end

  def test_files(sha)
    files_at_commit(sha, test_file_filter)
  end

  def test_lines(sha)
    count_lines(test_files(sha))
  end

  def num_test_cases(sha)
    count_lines(test_files(sha), test_case_filter)
  end

  def num_assertions(sha)
    count_lines(test_files(sha), assertion_filter)
  end

  def gh_test_cases_per_kloc(sha)
    test_case_number = num_test_cases(sha)
    return nil if test_case_number.nil?
    src_line_number = src_lines(sha)
    return test_case_number / (src_line_number.to_f / 1000)
  end

  def gh_asserts_cases_per_kloc(sha)
    assertion_number = num_assertions(sha)
    return nil if assertion_number.nil?
    src_line_number = src_lines(sha)
    return assertion_number / (src_line_number.to_f / 1000)
  end

  def start_per_sloc
    Thread.abort_on_exception = true
    threads = init_persloc
    puts " start_per_sloc==="
    
    # All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=?  and sloc_flag=0 ",@first_id,@last_id,"#{@user}@#{@repo}").find_all do |info|
    All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=?  and sloc_flag=0 ",@first_id,@last_id,"#{@user}@#{@repo}").find_all do |info|
      puts "inqueue"
      @queue.enq info
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "Update Over"
  end

  def init_persloc
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          info = @queue.deq
          break if info == :END_OF_WORK
          test_ok=0
          test_fail=0
          i=0
          puts "info====#{info.build_id}"
      
          if i==0
             puts "sloc"
             test_den=gh_test_cases_per_kloc(info.now_build_commit)
             assert_den=gh_asserts_cases_per_kloc(info.now_build_commit)
             if !test_den.nil? and assert_den.nil?
              info.test_density=gh_test_cases_per_kloc(info.now_build_commit)
              info.assert_density=gh_asserts_cases_per_kloc(info.now_build_commit)
              info.sloc_flag=1
              info.save
             end

          end
          
        
        end
        end
        threads << thread
      end

    threads
    
  end
  def count_lost_num
    # p All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=? and last_label=-1 and consec_fail_builds_sum is null",@first_id,@last_id,"#{@user}@#{@repo}").count
    p All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=? and last_label=1 and last_fail_gap_sum is null",@first_id,@last_id,"#{@user}@#{@repo}").count
  end
end
