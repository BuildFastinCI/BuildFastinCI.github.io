def self.thread_init
    @queue = SizedQueue.new(@thread_num)
    threads = []
    @thread_num.times do
      thread = Thread.new do
        loop do
          job_file_path = @queue.deq
          break if job_file_path == :END_OF_WORK
          parse_job_json_file(job_file_path[0],job_file_path[1])
        end
      end
      threads << thread
    end
    threads
  end

  def self.scan_files(json_files_path, id)
    threads = thread_init
    

    Build.find_by_sql('SELECT repositories.repo_name FROM builds 
    inner join repositories where repository_id=repositories.id group by repository_id').find_all do |repo|
      repo_name = repo.repo_name
      
      puts "Scan project #{repo_name}"
      repo_json_path = File.join(json_files_path, repo_name.sub(/\//,'@'))
      #next unless File.exist? repo_json_path
      repo_log_path = repo_json_path.sub(/json_files/, 'build_logs')
      FileUtils.mkdir_p(repo_log_path) unless File.exist?(repo_log_path)
      job_file=[]
      Dir.foreach(repo_json_path) do |job_file_name|
        next if job_file_name !~ /job@.+@.+/
        #####new method to quickly filter the files that should be downloaded
        job_file << job_file_name.sub(/job@/,'').sub(/\.json/,'')  
      end
      log_file=[]
      log_file_dir = repo_json_path.sub(/json_files/, 'build_logs')
      Dir.foreach(log_file_dir) do |log_file_name|
        next if log_file_name !~ /@.+log+/
        log_file << log_file_name.sub(/\.log/,'')
      end
      miss_job=[]
      miss_job= job_file-log_file
      miss_job.each do |missed_job|
        job_file_path = File.join(repo_json_path,'job@'+ missed_job+'.json')
        # p job_file_path
        @queue.enq [job_file_path,repo_name]
      end

      # p job_file-log_file
      # job_file_path = File.join(repo_json_path, job_file_name)
      
      # @queue.enq [job_file_path,repo_name]
    end
    @thread_num.times do
      @queue.enq :END_OF_WORK
    end
    threads.each { |t| t.join }
    puts "=====================Scan over==================="
  end
