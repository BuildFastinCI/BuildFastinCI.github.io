require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual.rb',__FILE__)
#require File.expand_path('../../lib/commit_info.rb',__FILE__)
# require File.expand_path('../../lib/maven_error.rb',__FILE__)
require File.expand_path('../../bin/download_job.rb',__FILE__)
module TestNum
    

  def self.extract_test(hash)
    begin
      file_array = IO.readlines(hash[:log_path])
    rescue#不存在file
      puts "begin"
      DownloadJobs.job_logs(hash[:log_path],hash[:job_id])
      
      if File.exists?(hash[:log_path]) and File.size(hash[:log_path]) > 5
        file_array = IO.readlines(hash[:log_path])
      else
        puts "can not download"
        file_array=[]
      end
    ensure
      if file_array.nil?#null的情况
       
        DownloadJobs.job_logs(hash[:log_path],hash[:job_id])
      
        if File.exists?(hash[:log_path]) and File.size(hash[:log_path]) > 5
          file_array = IO.readlines(hash[:log_path])
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
        if file_array.scan(/(Reactor Summary|mvn test)/m).size >= 2
            flag='maven'
          elsif @logFile.scan(/gradle/m).size >= 2
            flag='gradle'
          elsif @logFile.scan(/ant/m).size >= 2
            flag='ant'
          else
            # default back to Ant if nothing else found
            flag='ant'
          end
        return
        file_array.each do |line|
            # maven
            if !(line =~ /Tests run: .*? Time elapsed: (.* sec)/).nil?
            init_tests
            @tests_run = true
            # add_framework 'junit'
            # @test_duration += convert_maven_time_to_seconds $1
            elsif !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*)(, Skipped: (\d*))?/).nil?
         
            @tests_run = true
            # add_framework 'junit'
            @num_tests_run += $1.to_i
            @num_tests_failed += $2.to_i + $3.to_i
            @num_tests_skipped += $5.to_i unless $4.nil?
            elsif !(line =~ /Total tests run:(\d+), Failures: (\d+), Skips: (\d+)/).nil?
            
            # add_framework 'testng'
            @tests_run = true
            @num_tests_run += $1.to_i
            @num_tests_failed += $2.to_i
            @num_tests_skipped += $3.to_i
            elsif !(line =~ /(Failed tests:)|(Tests in error:)/).nil?
                @test_failed = true
            
            end
             
            
        end

        if @num_tests_run==0
            #gradle
            file_array.each do |line|
                init_tests  
            if !(line =~ /.* > .* FAILED/).nil?
                @tests_failed_lines << line
                @test_failed = true
            end
        
            if !(line =~ /(\d*) tests completed, (\d*) failed, (\d*) skipped/).nil?
                
            
                @num_tests_run += $1.to_i
                @num_tests_failed += $2.to_i
                @num_tests_skipped += $3.to_i
            elsif !(line =~ /Total tests run:(\d+), Failures: (\d+), Skips: (\d+)/).nil?
                init_tests
                
                @tests_run = true
                @num_tests_run += $1.to_i
                @num_tests_failed += $2.to_i
                @num_tests_skipped += $3.to_i
            elsif !(line =~ /Result)

            end
        
            
            end
        
            
        end

        if @num_tests_run==0
          file_array.each do |line|
            if !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*), (Skipped: (\d*), )?Time elapsed: (.*)/).nil?
              init_tests
              
              @tests_run = true
              @num_tests_run = $1.to_i
              @num_tests_failed = $2.to_i + $3.to_i
              @num_tests_skipped += $5.to_i unless $4.nil?
            #   @test_duration = convert_ant_time_to_seconds($6)
            elsif !(line =~ /Total tests run:(\d+), Failures: (\d+), Skips: (\d+)/).nil?
              init_tests
              
              @tests_run = true
              @num_tests_run += $1.to_i
              @num_tests_failed += $2.to_i
              @num_tests_skipped += $3.to_i
            elsif !(line =~ /Failed tests:/).nil?
                @test_failed  = true
            elsif !(line =~ /Test (.*) failed/).nil?
                @test_failed =  true
            end

        end
    end
        
    All_repo_data_virtual_prior_merge.where("build_id=?",hash[:build_id]).find_each do |tmp_relation|
        if !@num_tests_run.nil? and !@num_tests_failed.nil?
            if !tmp_relation.tr_log_num_tests_ok.nil?
                tmp_relation.tr_log_num_tests_ok+=@num_tests_run-@num_tests_failed
            else
                tmp_relation.tr_log_num_tests_ok=@num_tests_run-@num_tests_failed
            end
            if !tmp_relation.tr_log_num_tests_fail.nil?
                tmp_relation.tr_log_num_tests_fail+=@num_tests_failed
            else
                tmp_relation.tr_log_num_tests_fail=@num_tests_failed
            
            end
            
            tmp_relation.save
        else
            tmp_relation.tr_log_num_tests_ok=nil
            tmp_relation.tr_log_num_tests_fail=nil
            tmp_relation.save
        end
    end
    end
       
end

def self.init_tests
  
    @test_duration = 0
    @num_tests_run = 0
    @num_tests_failed = 0
    @num_tests_ok = 0
    @num_tests_skipped = 0

    @num_test_suites_run = nil
    @num_test_suites_ok = nil
    @num_test_suites_failed = nil

    @test_failed=false
  
end


def self.init_save_maven_errors
    @inqueue = SizedQueue.new(5)
    threads=[]
    5.times do 
      thread = Thread.new do
        loop do
          hash = @inqueue.deq
          break if hash == :END_OF_WORK
          extract_test hash
          
          
          end
        end
        threads << thread
      end
  
    threads
  ends

def self.save_maven_errors(user,repo)
    Thread.abort_on_exception = true
  
    
    threads=init_save_maven_errors
    
    @inqueue.enq hash
  
    # All_repo_data_virtual.where("build_id=?",item).find_each do |info|
    #   i=0
    #   for job in info.jobs_state
        
    #       hash = Hash.new
    #       log_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', info.repo_name, info.jobs_arry[i].sub(/\./, '@')+'.log'), File.dirname(__FILE__))
      
          
    #       hash[:job_number]=info.jobs_arry[i]
    #       hash[:job_id]=info.jobs[i] 
          
          
    #       hash[:log_path]=log_path
          
    #       hash[:build_id]=item#last_build_id
    #       hash[:log_path]=log_path
    #       @inqueue.enq hash
        
    #     i=i+1
    #   end
    # end
  
    5.times do
        @inqueue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "Update Over"

end


end