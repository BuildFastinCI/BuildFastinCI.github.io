
require 'json'
require 'fileutils'
require_relative 'job'
require_relative 'cll_tests'
require_relative 'cll_failedtests'
require_relative'job_log'
require 'activerecord-import'
module TestNum
    
  @thread_num=20
  $test_id=[]
  # $job_info=[]
  def self.extract_test(hash)
    begin
      file_array = IO.readlines(hash[:log_path])
    rescue#不存在file
      puts "begin"
      DownloadJobs.download_job(hash[:job_id],hash[:log_path])
      
      if File.exists?(hash[:log_path]) and File.size(hash[:log_path]) > 5
        file_array = IO.readlines(hash[:log_path])
      else
        puts "can not download"
        file_array=[]
      end
    ensure
      if file_array.nil?#null的情况
       
        DownloadJobs.download_job(hash[:job_id],hash[:log_path])
      
        if File.exists?(hash[:log_path]) and File.size(hash[:log_path]) > 5
          file_array = IO.readlines(hash[:log_path])
        else
          puts "can not download2"
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
        flag=nil
        flag_maven,flag_gradle,flag_ant=0,0,0
        file_array.each do |line|
          if line.scan(/(Reactor Summary|mvn test)/m).size >= 1
            flag_maven+=1
            
          elsif line.scan(/gradle/m).size >= 1
            flag_gradle+=1
            
          elsif line.scan(/ant/m).size >= 1
            flag_ant+=1
            
          else
            
            flag='ant'
          end
        end
        if flag_maven>=2
          flag='maven'
        elsif flag_gradle>=2
          flag='gradle'
        elsif flag_ant>=2
          flag='ant'
        else 
          flag='ant'
        end
        # p flag
        # extract_method=LogtypeExtract.new
        # if flag=='maven'
        #   test_lines,reactor_lines=extract_method.maven_extract(file_array)
        # elsif flag=='gradle'
        #   test_lines,reactor_lines=extract_method.gradle_extract(file_array)
        # else
        #   test_lines,reactor_lines=extract_method.ant_extract(file_array)
        # end

       
        # test_lines.each do |lines|
        #   p lines
          
        # end
        
        
         parse_test(flag,file_array,hash[:id])
      end

  end
  


  def self.convert_maven_time_to_seconds(string)
    if !(string =~ /((\d+)(\.\d*)?) s/).nil?
      return $1.to_f.round(2)
    elsif !(string =~ /(\d+):(\d+) min/).nil?
      return $1.to_i * 60 + $2.to_i
    end
    return 0
  end

  def self.convert_gradle_time_to_seconds(string)
    if !(string =~ /((\d+) mins)? (\d+)(\.\d+) secs/).nil?
      return $2.to_i * 60 + $3.to_i
    end
    return 0
  end

  def self.convert_ant_time_to_seconds(string)
    if !(string =~ /((\d+)(\.\d*)?) s/).nil?
      return $1.to_f.round(2)
    elsif !(string =~ /(\d+):(\d+) min/).nil?
      return $1.to_i * 60 + $2.to_i
    end
    return 0
  end

  def self.parse_test(flag,file_array,jobs_id)
    
    @init_tests=false
    init_tests
    reactor_time=0
    if flag=='maven' 
      count=0
      file_array.each do |line|
          # maven
          
          if !(line =~ /Result/).nil?

          end
          if !(line =~ /Tests run: .*? Time elapsed: (.* s)/).nil?
            init_tests
            @tests_run = true
          # add_framework 'junit'
            # p $1
            @test_duration += convert_maven_time_to_seconds $1
          elsif !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*)(, Skipped: (\d*))?/).nil?
          
          @tests_run = true
          # add_framework 'junit'
          
          @num_tests_run += $1.to_i
          @num_tests_failed += $2.to_i 
          @num_tests_errored +=$3.to_i
          @num_tests_skipped += $5.to_i unless $4.nil?
          
          elsif !(line =~ /Total tests run:(\d+), Failures: (\d+), Skips: (\d+)/).nil?
          
          # add_framework 'testng'
         
          @tests_run = true
          @num_tests_run += $1.to_i
          @num_tests_failed += $2.to_i
          @num_tests_skipped += $3.to_i
          
          
          elsif !(line =~ /(Failed tests:)|(Tests in error:)/).nil?
              @test_failed = true
          
          elsif !(line =~ /\[INFO\] .*test.*? (\w+) \[ (.+)\]/i).nil?
            reactor_time += convert_maven_time_to_seconds($2)
          
          end
          if !(line =~ /\[INFO\] .*test.*? (\w+) \[ (.+)\]/i).nil?
            reactor_time += convert_maven_time_to_seconds($2)
          end
          
          
      end
      # p @num_tests_run
      # p @num_tests_failed
      # p @num_tests_skipped
      # p @num_tests_errored    
    elsif flag=='gradle'
      if @num_tests_run==0
          #gradle
          test_flag=0
          file_array.each do |line|
          if !(line =~ /\A:(test|integrationTest)/).nil? 
            test_flag=1
          end
          if !(line =~ /.* > .* FAILED/).nil? && test_flag==1
              init_tests
              
              @test_failed = true
          end
      
          if !(line =~ /(\d*) tests completed, (\d*) failed, (\d*) skipped/).nil?
              p "tests completed"
              init_tests 
              @num_tests_run += $1.to_i
              @num_tests_failed += $2.to_i
              @num_tests_skipped += $3.to_i
          elsif !(line =~ /Total tests run:(\d+), Failures: (\d+), Skips: (\d+)/).nil?
              init_tests
              
              @tests_run = true
              @num_tests_run += $1.to_i
              @num_tests_failed += $2.to_i
              @num_tests_skipped += $3.to_i
          
          elsif !(line =~ /Total time: (.*)/).nil?
              @test_duration= convert_gradle_time_to_seconds($1)
          end
      
          
      end
      
      
          
      end
    else #ant
      if @num_tests_run==0
        file_array.each do |line|
          if !(line =~ /Tests run: (\d*), Failures: (\d*), Errors: (\d*), Skipped: (\d*), Time elapsed: (.*)/).nil?
            init_tests
            
            @tests_run = true
            @num_tests_run = $1.to_i
            @num_tests_failed = $2.to_i 
            @num_tests_errored = $3.to_i
            @num_tests_skipped += $4.to_i
            @test_duration = convert_ant_time_to_seconds($6)
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
    end

    job_info=Hash.new

    job_info={
      :id => jobs_id,
      :cll_testsfailed =>  if (@test_failed or @num_tests_failed>0 or @num_tests_errored>0) 
                              true 
                            else 
                              false 
                            end,
      :cll_testsrun => @num_tests_run,
      :cll_testsfailure => @num_tests_failed,
      :cll_testserror => @num_tests_errored,
      :cll_testsskip => @num_tests_skipped,
      :cll_test_duration => @test_duration,
      :cll_type=> if flag=='maven'
                    1
                  elsif flag=='gradle'
                    2
                  elsif flag=='ant'
                    3
                  end

    } 
    if job_info[:cll_test_duration].nil? || reactor_time > job_info[:cll_test_duration]
      job_info[:cll_test_duration] = reactor_time
    end 
    # analyze_reactor(job_info,reactor_lines)
    p "outqueue"
    # p job_info
    @outqueue.enq  job_info
    
  end

  def self.analyze_reactor(job_info,reactor_lines)
    reactor_time = 0
    @pure_build_duration=0
    reactor_lines.each do |line|
      if !(line =~ /\[INFO\] .*test.*? (\w+) \[ (.+)\]/i).nil?
        reactor_time += convert_maven_time_to_seconds($2)
      # elsif !(line =~ /Total time: (.+)/i).nil?
        # @pure_build_duration = convert_maven_time_to_seconds($1)
      end
    end
    if job_info[:cll_test_duration].nil? || reactor_time > job_info[:cll_test_duration]
      job_info[:cll_test_duration] = reactor_time
    end
     job_info
  end

  def self.init_tests
    unless @init_tests
      @test_duration = 0
      @num_tests_run = 0
      @num_tests_failed = 0
      @num_tests_errored=0
      @num_tests_ok = 0
      @num_tests_skipped = 0

      @num_test_suites_run = nil
      @num_test_suites_ok = nil
      @num_test_suites_failed = nil

      @test_failed=false
      @init_tests=true
    end
    
  end


  def self.init_save_maven_errors
      @inqueue = SizedQueue.new(@thread_num)
      
      @outqueue = SizedQueue.new(200)
      consumer = Thread.new do
        id = 0
        loop do
          bulk = []
          hash = nil
          200.times do
            hash = @outqueue.deq
            break if hash == :END_OF_WORK
            bulk << Cll_test.new(hash)
          end
          Cll_test.import bulk
          p "imported"
          break if hash == :END_OF_WORK
        end
      end

      threads=[]
      @thread_num.times do 
        thread = Thread.new do
          loop do
            hash = @inqueue.deq
            break if hash == :END_OF_WORK
            if hash[:exist_id].include? hash[:id]
                $test_id=$test_id-[job.id]
                break
            end
            extract_test hash
            
            
            end
          end
          threads << thread
        end
    
      [consumer, threads]
  end

  def self.save_maven_errors(user,repo)
    p "into save"
      Thread.abort_on_exception = true
      hash = Hash.new
      # log_path=json_files_path = File.expand_path(File.join('..','build_logs/ome@bioformats/1755@1.txt', File.dirname(__FILE__)))
      
      consumer,threads=init_save_maven_errors
      # hash[:log_path]=log_path
      # hash[:job_id]=92277487
      # @inqueue.enq hash
      
      
      Cll_test.where("id>=0").find_each do |test|
          $test_id << test.id
      end
      
      Job.where("id>0 and test_failed = false").find_each do |job|
        hash = Hash.new
        # if test_id.include? job.id
        #   test_id=test_id-[job.id]
        #   next
        # end
        hash[:id]=job.id
        hash[:job_id]=job.job_id
        hash[:job_number]=job.job_number
        
        log_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', job.repo_name.sub(/\//,'@'), job.job_number.sub(/\./, '@')+'.log'), File.dirname(__FILE__))
        # p log_path
        hash[:log_path]=log_path
        hash[:exist_id]=$test_id
        
        @inqueue.enq hash
      end
      
    
      @thread_num.times do
          @inqueue.enq :END_OF_WORK
      end
      
      threads.each {|t| t.join}
      @outqueue.enq(:END_OF_WORK)
      consumer.join
      puts "Update Over"

  end
  
  def self.test(user,repo)
    Thread.abort_on_exception = true
    hash = Hash.new
    log_path=json_files_path = File.expand_path(File.join('..','1755@1.txt', File.dirname(__FILE__)))
    
    consumer,threads=init_save_maven_errors
    # hash[:log_path]=log_path
    # hash[:job_id]=92277487
    # @inqueue.enq hash
    
      hash[:id]=49305
      hash[:job_id]=117463176
      hash[:job_number]='1338.5'
      
      # log_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', 'openmicroscopy@bioformats', hash[:job_number].sub(/\./, '@')+'.log'), File.dirname(__FILE__))
      hash[:log_path]=log_path
      
      @inqueue.enq hash
    
    
  
    @thread_num.times do
        @inqueue.enq :END_OF_WORK
    end
    
    threads.each {|t| t.join}
    @outqueue.enq :END_OF_WORK
    consumer.join
    puts "Update Over"

end

end
TestNum.save_maven_errors('','')
# TestNum.test("","")