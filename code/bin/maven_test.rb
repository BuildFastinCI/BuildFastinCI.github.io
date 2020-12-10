 require File.expand_path('../../lib/maven_error.rb',__FILE__)
 require File.expand_path('../download_job.rb',__FILE__)    
module MavenTest
    
  
    def self.test_error_message_slice(log_hash)
        file_array=[]
        begin
            file_array = IO.readlines(log_hash.log_path)
        rescue#不存在file
            puts "begin" 
            DownloadJobs.job_logs(log_hash.log_path,log_hash.job_id)
            
            if File.exists?(log_hash.log_path) and File.size(log_hash.log_path) > 5
                file_array = IO.readlines(log_hash.log_path)
            else
                puts "can not download"
                file_array=[]
            end
        ensure
            if file_array.size<2#null的情况
                DownloadJobs.job_logs(log_hash.log_path,log_hash.job_id)
            
                if File.exists?(log_hash.log_path) and File.size(log_hash.log_path) > 5
                file_array = IO.readlines(log_hash.log_path)
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
            
            
            
            puts "MSLICE=========="
            
            '''
            #gslice = gradle_slice(file_array.reverse!) if log_hash[:gradle]
            
            # hash = Hash.new
            # hash[:repo_name] = log_hash[:repo_name]
            # hash[:job_number] = log_hash[:job_number]
            # hash[:job_id] = log_hash[:job_id]
            '''
        
            failed_slice,test_error_slice=test_maven_slice(file_array)
            if failed_slice.length > 0
            log_hash[:maven_slice]=failed_slice
            log_hash.save
            end
            if test_error_slice.length>0
            log_hash[:test_in_error]=test_error_slice
            log_hash.save
            end
            #ActiveRecord::Base.clear_active_connections!
        end

    end

    
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


    def self.init_save_maven_errors
        @inqueue = SizedQueue.new(30)
        threads=[]
        30.times do 
        thread = Thread.new do
            loop do
            info = @inqueue.deq
            break if info == :END_OF_WORK
            test_error_message_slice info
            
            
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
        Maven_error.where("repo_name=? and test=1","#{user}@#{repo}").find_all do |info|
        @inqueue.enq info
        end
        
        
    
        30.times do
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        
        
    #
        puts "Update Over"  
    end
end

  user=ARGV[0]
  repo=ARGV[1]
  
  #init_save_maven_errors
  #test_maven_slice(arry)
  #save_maven_errors(user,repo)
  #test_error_message_slice(arry)
#   Maven_error.where("repo_name=? and test=1","#{user}@#{repo}").find_all do |info|
#     puts info[:job_id]
#     puts info[:job_id].class 
#     break   
    