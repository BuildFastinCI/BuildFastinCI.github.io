#require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual.rb',__FILE__)
#require File.expand_path('../../lib/commit_info.rb',__FILE__)
require File.expand_path('../../lib/maven_error.rb',__FILE__)
require File.expand_path('../download_job.rb',__FILE__)
MAVEN_ERROR_FLAG = /COMPILATION ERROR/
MAVEN_WARNING_FLAG = /COMPILATION WARNING/
GRADLE_ERROR_FLAG = /> Compilation failed; see the compiler error output for details/
GRADLE_ERROR_FLAG_1 = /Compilation failed|Compilation error/
GRADLE_ERROR_UP_BOUNDARY = /:compileTestJava|:compileJava|:compileKotlin|:compileTestKotlin|:compileGroovy|:compileTestGroovy|:compileScala|:compileTestScala|\.\/gradle|travis_time/
SEGMENT_BOUNDARY = "/home/travis"
SEGMENT_BOUNDARY_FILE = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.(java|groovy|scala|kt|sig)/
SEGMENT_BOUNDARY_JAVA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.java/
SEGMENT_BOUNDARY_GROOVY = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.groovy/
SEGMENT_BOUNDARY_SCALA = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.scala/
SEGMENT_BOUNDARY_KOTLIN = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.kt/
SEGMENT_BOUNDARY_SIG = /(\/[^\n\/]+){2,}\/\w+[\w\d]*\.sig/
SEGMENT_BOUNDARY_JAR = /(\/[^\n\/]+){2,}\/\w+[-\w\d]*\.jar/
SEGMENT_BOUNDARY_JAVAC_ERROR = /Failure executing javac, but could not parse the error/
$error_info=["failed","errored"]
# file_arry=["[ERROR] COMPILATION ERROR : "]
# puts MAVEN_ERROR_FLAG =~ file_arry[0]
def self.test_maven_slice(file_array)
  failed_tests = []
  file_array.each do |line|     
    if !(line =~ /Failed tests:/).nil?
      failed_tests << line
      break
    end
    if !(line =~ /Tests in error:/).nil?
      failed_tests << line
      break
    end

    
  end
  return failed_tests

end
  
  def self.maven_slice(file_array)
    array = []
    flag = false
    temp = nil
    file_array.each do |line|
      # 
      if MAVEN_ERROR_FLAG =~ line
        flag = true 
        temp = [] 
      end
      temp << line if flag
      if flag && line =~ /[0-9]+ error|Failed to execute goal/
        flag = false 
        s = temp.join
        temp = nil
        mark = true
        array.each do |item|
          mark = false if item.eql?(s)
        end
        array << s if mark
      end
    end
    array << temp.join if temp
    
    return array 
    
  end
  
  def self.compiler_error_message_slice(log_hash)
    begin
    file_array = IO.readlines(log_hash[:log_path])
    rescue#不存在file
      puts "begin"
      DownloadJobs.job_logs(log_hash[:log_path],log_hash[:job_id])
      
      if File.exists?(log_hash[:log_path]) and File.size(log_hash[:log_path]) > 5
        file_array = IO.readlines(log_hash[:log_path])
      else
        puts "can not download"
        file_array=[]
      end
    ensure
      if file_array.size<2#null的情况
        DownloadJobs.job_logs(log_hash[:log_path],log_hash[:job_id])
      
        if File.exists?(log_hash[:log_path]) and File.size(log_hash[:log_path]) > 5
          file_array = IO.readlines(log_hash[:log_path])
        else
          puts "can not download"
          file_array=[]
        end
      end
      
    end
    if file_array.size > 1
      file_array.collect! do |line|
        begin
          sub = line.gsub(/\r\n?/, "\n")  
        rescue
          sub = line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/\r\n?/, "\n")
        end
        sub
      end
    
      mslice = []
      gslice = []
      
      mslice = maven_slice(file_array) #if log_hash[:maven]
      puts "MSLICE=========="
      
      '''
      #gslice = gradle_slice(file_array.reverse!) if log_hash[:gradle]
    
      # hash = Hash.new
      # hash[:repo_name] = log_hash[:repo_name]
      # hash[:job_number] = log_hash[:job_number]
      # hash[:job_id] = log_hash[:job_id]
      '''
      if mslice.length>0
      log_hash[:maven_slice] = mslice
      log_hash[:compliation]=1 
      else
      test_slice=test_maven_slice(file_array)
      log_hash[:maven_slice]=nil
      
        if !test_slice.empty?
          log_hash[:test]=1
        else
          log_hash[:other_error]=1
        end
      end
    
      #hash[:gradle_slice] = gslice.length > 0 ? gslice : nil
      # Maven_error.with_connection.do |conn|
      #     conn.new(log_hash)
      #     conn.save
      # end
      c=Maven_error.new(log_hash)
      c.save
    else
      log_hash[:log_exist]=1
      c=Maven_error.new(log_hash)
      c.save
    end

    #@out_queue.enq hash
  end

  def self.init_save_maven_errors
    @inqueue = SizedQueue.new(30)
    threads=[]
    20.times do 
      thread = Thread.new do
        loop do
          hash = @inqueue.deq
          break if hash == :END_OF_WORK
          compiler_error_message_slice hash
          
          
          end
        end
        threads << thread
      end

    threads
  end

  def self.save_maven_errors(user,repo)
    Thread.abort_on_exception = true
    #threads = init_update_last_build_status2
    
    threads=init_save_maven_errors
    All_repo_data_virtual.where("repo_name=? and status in ('errored','failed')","#{user}@#{repo}").find_all do |info|
      i=0
      
    for job in info.jobs_state
      if $error_info.include? job
      hash = Hash.new
      log_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', info.repo_name, info.jobs_arry[i].sub(/\./, '@')+'.log'), File.dirname(__FILE__))
   
      hash[:repo_name]=info.repo_name
      hash[:job_number]=info.jobs_arry[i]
      hash[:job_id]=info.jobs[i] 
      hash[:job_state]=job
      
      hash[:log_path]=log_path
      hash[:all_repo_data_virtual_id]=info.id
      hash[:build_id]=info.build_id
      hash[:log_path]=log_path
      @inqueue.enq hash
      end
      i=i+1
    end
  end
    20.times do
      @inqueue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    
    
   #
    puts "Update Over"

  end

  def self.maven_warning_slice(file_array)
    array = []
    flag = false
    temp = nil
    file_array.each do |line|
      if MAVEN_WARNING_FLAG =~ line
        flag = true
        temp = [] 
      end
      temp << line if flag
      if flag && line =~ /[0-9]+ warning|Failed to execute goal|COMPILATION ERROR/
        flag = false 
        s = temp.join
        temp = nil
        mark = true
        array.each do |item|
          mark = false if item.eql?(s)
        end
        array << s if mark
      end
    end
    array << temp.join if temp
    array
  end

user=ARGV[0]
repo=ARGV[1]
save_maven_errors(user,repo)


# log_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', 'google@guava', '1@3.log'), File.dirname(__FILE__))
# hash=Hash.new  
      
#     hash[:job_id]=40108475
    
#     hash[:log_path]=log_path
#     compiler_error_message_slice(hash)

  