require 'net/http'
require 'open-uri'
require 'json'

require 'fileutils'
require 'travis'
require 'uri'
require 'find'
require 'open_uri_redirections'
# require_relative 'respository'
# require_relative 'builds'

module DownloadJobs
  @thread_num=60
  def self.download_job(job_id,log_file_path)
    puts 'download jobs begin'
    # job_log_url="http://s3.amazonaws.com/archive.travis-ci.org/jobs/#{job_id}/log.txt"
    job_log_url="http://api.travis-ci.org/jobs/#{job_id}/log.txt"
    count = 0
    f = ''
    begin
      # return if File.exist? log_file_path
      if job_log_url.include?('jobs')
        # open(job_log_url,'Content-Type'=>'text/plain','Accept'=> 'text/plain',:allow_redirections => :all) { |o| f = o.read }
        
        # open(job_log_url,'Travis-API-Version'=>'3','Accept'=>' text/plain','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ',:allow_redirections => :all) { |o| f = o.read }
        puts"reopen #{job_log_url}"#xukZXnxq2DWJOJU4ETvQ5A
        open(job_log_url,'Travis-API-Version'=>'3','Accept'=>' text/plain','Authorization'=>'token C-cYiDyx1DUXq3rjwWXmoQ',:allow_redirections => :all) { |o| f = o.read }
        # open(job_log_url,'Content-Type'=>'text/plain','Accept'=>'application/vnd.travis-ci.2.1+json',:allow_redirections => :all) { |o| f = o.read }
        File.open(log_file_path, 'w') do |file|
            file.puts(f) end
      else
        # open(job_log_url,'Content-Type'=>'text/plain','Accept'=> 'application/vnd.travis-ci.2+json',:allow_redirections => :all) { |o| f = o.read }
        # repository = Travis::Repository.find(repos)
        # p "traivs job find"
        # p log_file_path
        job=Travis::Job.find(job_id)
        job.log.body { |chunk| File.open(log_file_path, 'w') do |file|
            file.puts(chunk) end}
        # open(job_log_url,'Content-Type'=>'text/plain','Accept'=> 'text/plain') { |o| f = o.read }
      end
    rescue => e
      puts "Retrying, #{count} times fail to download job log #{job_log_url}: #{e.message}"
    #   job_log_url = "http://api.travis-ci.org/jobs/#{job_id}/log.txt"  #if e.message.include?('403')
      job_log_url ="http://api.travis-ci.org/job/#{job_id}/log.txt"
      f = ''
      sleep 10
      count += 1
      retry if count < 3
    end
    
    # File.open(name, 'w') { |info| info.puts f }
    # puts "download logssssss"
    # f = ''
  end



def self.job_logs(job_id,repo_name,log_file_path)
  
    #name = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', 'google@guava', '1000@1.log'), File.dirname(__FILE__))
    
      
      download_job(job_id,log_file_path)
   
  
end


def self.parse_job_json_file(job_file_path,repo_name)
    log_file_path = job_file_path.sub(/json_files/, 'build_logs').sub(/job@/,'').sub(/\.json/,'.log')
    return if File.size?(log_file_path) && File.size?(log_file_path) >= 150
    puts "#{job_file_path}\n#{log_file_path}\n\n"
    begin
      j = JSON.parse IO.read(job_file_path)
      job_id = j['id']
    rescue
      regexp = /"number": "([.\d]+)"/
      IO.readlines(job_file_path).each do |line|
        break if regexp =~ line
      end
      job_id = $1
    end
    # f = job_id ? job_logs(job_id,repo_name) : nil
    job_logs(job_id,repo_name,log_file_path)
    # return unless f
    puts "Download log into #{log_file_path}"

    # File.open(log_file_path, 'w') do |file|
    #   file.puts(f)
    # end
  end

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

  def self.scan_json_files(json_files_path, id)
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

  def self.run
    Thread.abort_on_exception = true
    json_files_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 
        'json_files'), File.dirname(__FILE__))
    # json_files_path = File.expand_path(File.join('..','json_files', File.dirname(__FILE__)))
    # p json_files_path
    scan_json_files(json_files_path, 0)
  end
end 
