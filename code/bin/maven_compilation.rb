require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
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
$num_data=0
module MavenCompilation
  @thread_num=80
 
  def self.test_maven_slice(file_array)
    failed_tests = []
    tests_in_error=[]
    failed_tests_flag=false
    tests_in_error_started=false
    file_array.each do |line|     
        if !(line =~ /Failed tests:/).nil?
            failed_tests_flag=true
            
        end
        if !(line =~ /Tests in error:/).nil?
            tests_in_error_started = true
          end
        # if !(line =~ /Tests in error:/).nil?
        #     failed_tests << line
        #     break
        # end
        
        if failed_tests_flag
            if line.nil? || line.strip.empty? || line =~ /---/ || line =~ /Tests in error/
                failed_tests_flag = false
            end
            failed_tests << line
        end
        if tests_in_error_started
            if line.nil? || line.strip.empty? || line =~ /---/
              tests_in_error_started = false
            end
            tests_in_error << line
          end
    end
    [failed_tests,tests_in_error]

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
      if file_array.nil?#null的情况
       
        DownloadJobs.job_logs(log_hash[:log_path],log_hash[:job_id])
      
        if File.exists?(log_hash[:log_path]) and File.size(log_hash[:log_path]) > 5
          file_array = IO.readlines(log_hash[:log_path])
        else
          puts "can not download"
          file_array=[]
        end
      end
      
    end
    if !file_array.nil? and file_array.size > 2
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
      log_hash[:error_type]=1
      else
      failed_slice,test_error_slice=test_maven_slice(file_array)
        if failed_slice.length > 0
          log_hash[:fail_test]=failed_slice
          log_hash[:test]=1
          log_hash[:error_type]=2
          
        
        elsif test_error_slice.length>0
          log_hash[:test_inerror]=test_error_slice
          log_hash[:test]=1
          log_hash[:error_type]=2
        else
          log_hash[:other_error]=1
          log_hash[:error_type]=3
      
        end
    
    

      
      
      end
      today = Time.new; 

      
      log_hash[:insert_time]=today.strftime("%Y-%m-%d %H:%M:%S")
      #
      # c=Maven_error.new(log_hash)
      # c.save  
    else
      log_hash[:log_exist]=1
      # c=Maven_error.new(log_hash)
      # c.save
    end

    #@out_queue.enq hash
  end

  def self.init_save_maven_errors
    @inqueue = SizedQueue.new(@thread_num)
    threads=[]
    @thread_num.times do 
      thread = Thread.new do
        loop do
          
          hash = @inqueue.deq
          break if hash == :END_OF_WORK
          if Maven_error.where("job_id=? and repo_name=?  ",hash[:job_id],hash[:repo_name]).count>0#已经存进数据库了就跳过
            #puts "next#{hash[:job_id]}"
            next
          else
          compiler_error_message_slice hash
          end
          
          
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
    puts "save_maven_errors"
    repo_build_id=[]
    maven_build_id=[]
    left_id=[]
    All_repo_data_virtual.where("repo_name=? and status in ('errored','failed')","#{user}@#{repo}").find_all do |info|
      repo_build_id<<info.build_id
    end
    Maven_error.where("repo_name=?","#{user}@#{repo}").group("build_id").find_each do |info|
      maven_build_id << info.build_id
    end
    
    left_id=repo_build_id-maven_build_id
    for item in left_id #这是正确的写法，如果已经入库了就不重复
    
      All_repo_data_virtual.where("build_id=?",item).find_all do |info|
        i=0
     #puts "save error #{info.id}" 
        for job in info.jobs_state
          if $error_info.include? job
            hash = Hash.new
            # dir_path=File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', info.repo_name), File.dirname(__FILE__))
            dir_path=File.expand_path(File.join('..', 'bodyLog2', 'build_logs', info.repo_name), File.dirname(__FILE__))
            if !File.directory?(dir_path)
              FileUtils::mkdir_p(dir_path)
            end
            log_path = File.expand_path(File.join(dir_path, info.jobs_arry[i].sub(/\./, '@')+'.log'), File.dirname(__FILE__))
        
            hash[:repo_name]=info.repo_name
            hash[:job_number]=info.jobs_arry[i]
            hash[:job_id]=info.jobs[i] 
            hash[:job_state]=job
            
            hash[:log_path]=log_path
            hash[:all_repo_data_virtual_id]=info.id
            hash[:build_id]=info.build_id
            hash[:log_path]=log_path
            $num_data+=1
            @inqueue.enq hash
          end
          i=i+1
        end
      end
    end
    @thread_num.times do
      @inqueue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
  ending=Time.now
    ActiveRecord::Base.clear_active_connections!
    puts "Maven_errorUpdate Over"
    
    return $num_data,ending-starting
  end



  def self.dependency_error(user,repo)
    Thread.abort_on_exception = true
    threads=init_dependency_errors
    puts "save_dependency_error"
    Maven_error.where("repo_name=? and other_error=1","#{user}@#{repo}").find_all do |item|
      @inqueue.enq item
    end
    @thread_num.times do
      @inqueue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    ActiveRecord::Base.clear_active_connections!
    puts "Maven_denpendency Over"
  end
  def self.init_dependency_errors
    @inqueue = SizedQueue.new(@thread_num)
    threads=[]
    @thread_num.times do 
      thread = Thread.new do
        loop do
          
          info = @inqueue.deq
          break if info == :END_OF_WORK
          begin
            file_array = IO.readlines(info.log_path)
            rescue#不存在file
              puts "begin"
              DownloadJobs.job_logs(info.log_path,info.job_id)
              
              if File.exists?(info.log_path) and File.size(info.log_path) > 5
                file_array = IO.readlines(info.log_path)
              else
                puts "can not download"
                file_array=[]
              end
            ensure
              if file_array.nil?#null的情况
               
                DownloadJobs.job_logs(info.log_path,info.job_id)
              
                if File.exists?(info.log_path) and File.size(info.log_path) > 5
                  file_array = IO.readlines(info.log_path)
                else
                  puts "can not download"
                  file_array=[]
                end
              end
              
            end
            if !file_array.nil? and file_array.size > 2
              file_array.collect! do |line|
                begin
                  sub = line.gsub(/\r\n?/, "\n")  
                rescue
                  sub = line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/\r\n?/, "\n")
                end
                sub
              end
              file_array.each do |line|
                # 
                if !line.match(/[dD]ependenc?/).nil?
                  puts "====="
                  info.dependency=1
                  info.save
                  break
              end
            end
          end
          
          
        end
        end
        threads << thread
      end

    threads
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
  

end 

user=ARGV[0]
repo=ARGV[1]
# p MavenCompilation.save_maven_errors(user,repo)
# All_repo_data_virtual.find_by_sql ("SELECT build_id FROM cll_data.all_repo_data_virtual_prior_merges WHERE id=?",23317).find_each do |item|
#   p item.build_id
# end
# log_path="/home/fdse/user/zc/bodyLog2/build_logs/structr@structr/96@1.log"
# job_id='4526561'
# begin
#   file_array = IO.readlines()
#   rescue#不存在file
#     puts "begin"
#     DownloadJobs.job_logs(log_path,job_id)
    
#     if File.exists?(log_path) and File.size(log_path) > 5
#       file_array = IO.readlines(log_path)
#     else
#       puts "can not download"
#       file_array=[]
#     end
#   ensure
#     if file_array.nil?#null的情况
     
#       DownloadJobs.job_logs(log_path,job_id)
    
#       if File.exists?(info.log_path) and File.size(info.log_path) > 5
#         file_array = IO.readlines(info.log_path)
#       else
#         puts "can not download"
#         file_array=[]
#       end
#     end
    
#   end
#   if !file_array.nil? and file_array.size > 2
#     file_array.collect! do |line|
#       begin
#         sub = line.gsub(/\r\n?/, "\n")  
#       rescue
#         sub = line.encode('ISO-8859-1', 'ISO-8859-1').gsub(/\r\n?/, "\n")
#       end
#       sub
#     end
#     file_array.each do |line|
#       # 
#       if !line.match(/[dD]ependenc?/).nil?
#         puts "====="
#         info.dependency=1
#         info.save
#         break
#     end
#   end
# end

  