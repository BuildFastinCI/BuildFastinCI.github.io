require 'rugged'
require_relative 'java'
require 'open-uri'
class ExtractGitInfoGh

  include JavaData

  def initialize(user,repo)
    @token = ["baeb194686215604af80044f10ef4ffb32c903cb",
              
    ]
    @dir_name = "repo"
    dir_path = File.expand_path(@dir_name, File.dirname(__FILE__))
    Dir.mkdir(dir_path) if Dir.exists?(dir_path) == false
    @user=user
    @repo=repo
    @thread_number=30
    info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
    @first_id=info.now_build_id
    p @first_id
    last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
    
    @last_id=last_info.now_build_id
    p @last_id
    # checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository',user+'@'+repo),File.dirname(__FILE__))
    # # puts checkout_dir
    # @git = Rugged::Repository.new(checkout_dir)
  end
# url = "https://github.com/checkstyle/checkstyle/archive/354124f81461a8d6ba2264be07c5ea52c0ef05d9.zip"
  def download_zip(url, file_path)
    `wget #{url} -O #{file_path}`
    $?.success?
  end

  def unpack_zip(file_path, dir_path)
    `unzip #{file_path} -d repo/`
  end


  def all_files(dir_path, filter = lambda { |x| true })
    files = []
    begin
      Dir.chdir(dir_path)
      Dir.glob("**/*.java").each do |f|
      file = Hash.new
      file[:name] = f
      file[:path] = File.join(dir_path, f)
      files << file
      end
    rescue => exception
      puts "no such file"
    end
    
    if files.size <= 0
      puts "No files for commit #{dir_path}"
    end
    files.select { |x| filter.call(x) }
  end

  def run(repo_name, sha)
    url = "https://github.com/#{repo_name}/archive/#{sha}.zip"
    file_path = File.expand_path(File.join(@dir_name, "#{repo_name.sub(/\//, '@')}-#{sha}.zip"), File.dirname(__FILE__))
    download_exit_status = false
    download_exit_status = download_zip(url, file_path) if !File.exists?(file_path) == true
    return [nil, nil] if download_exit_status == false
    start = repo_name.index("/")
    puts repo_name
    puts"start #{start}"
    dir_path = File.expand_path(File.join(@dir_name, "#{repo_name[start..-1]}-#{sha}"), File.dirname(__FILE__))
    unpack_zip(file_path, dir_path) if File.exists?(dir_path) == false
    src_line_number = src_lines(dir_path)
    p src_line_number
    test_case_number = num_test_cases(dir_path)
    p test_case_number
    gh_test_cases_per_kloc = test_case_number / (src_line_number.to_f / 1000)
    assertion_number = num_assertions(dir_path)
    p assertion_number
    gh_asserts_cases_per_kloc = assertion_number / (src_line_number.to_f / 1000)
    return [gh_test_cases_per_kloc, gh_asserts_cases_per_kloc]
  end

  def stripped(f)
    @stripped ||= Hash.new
    unless @stripped.has_key? f
      @stripped[f] = strip_comments(File.read(f[:path]))
    end
    @stripped[f]
  end

  def count_lines(files, include_filter = lambda { |x| true })
    return nil if files.nil?
    files.map { |f|
      stripped(f).lines.select { |x|
        not x.strip.empty?
      }.select { |x|
        include_filter.call(x)
      }.size
    }.reduce(0) { |acc, x| acc + x }
  end

  def src_files(dir_path)
    all_files(dir_path, src_file_filter)
  end

  def src_lines(dir_path)
    count_lines(src_files(dir_path))
  end

  def test_files(dir_path)
    all_files(dir_path, test_file_filter)
  end

  def test_lines(dir_path)
    count_lines(test_files(dir_path))
  end

  def num_test_cases(dir_path)
    count_lines(test_files(dir_path), test_case_filter)
  end

  def num_assertions(dir_path)
    count_lines(test_files(dir_path), assertion_filter)
  end
  def start_per_sloc
    Thread.abort_on_exception = true
    threads = init_persloc
    puts " start_per_sloc==="
    
    All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=?  and ((sloc_flag=1 and test_density is null) or sloc_flag=0 )",@first_id,@last_id,"#{@user}@#{@repo}").find_all do |info|
      
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

          gh_test_cases_per_kloc, gh_asserts_cases_per_kloc = run(info.repo_name.gsub('@','/'), info.now_build_commit)
          info.test_density=gh_test_cases_per_kloc
          info.assert_density=gh_asserts_cases_per_kloc
          info.sloc_flag=1
          info.save
          
        end
        end
        threads << thread
      end

    threads
    
  end

end
dir = Dir.open("../")

