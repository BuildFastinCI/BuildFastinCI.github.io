
require_relative 'job'
require_relative 'cll_tests'
require_relative 'cll_failedtests'



module InsertJob
    @thread_num=40 

def self.init_save_maven_errors
    @inqueue = SizedQueue.new(@thread_num)
    
    

    threads=[]
    @thread_num.times do 
      thread = Thread.new do
        loop do
          hash = @inqueue.deq
          break if hash == :END_OF_WORK
          
          jobs=hash[0]
          tests=hash[1]
          jobs.cll_testsfailed=tests.cll_testsfailed
          jobs.cll_testsrun=tests.cll_testsrun
          jobs.cll_failure=tests.cll_testsfailure
          jobs.cll_error=tests.cll_testserror
          jobs.cll_skip=tests.cll_testsskip
          jobs.cll_type=tests.cll_type
          jobs.cll_test_duration=tests.cll_test_duration
          jobs.save
          end
        end
        threads << thread
      end
  
    threads
    end

    def self.save_maven_errors
        p "into save"
        Thread.abort_on_exception = true
        
        # log_path=json_files_path = File.expand_path(File.join('..','build_logs/ome@bioformats/1755@1.txt', File.dirname(__FILE__)))
        
        consumer,threads=init_save_maven_errors
        # hash[:log_path]=log_path
        # hash[:job_id]=92277487
        # @inqueue.enq hash
        
        test_id=[]
        Cll_failedtest.where("id>=0").find_each do |tests|
            
            Job.where("id=? and cll_testsfailed is not null",tests.id).find_each do |jobs|
        
                @inqueue.enq [jobs,tests]
                
                
            end
            
        end
        
        
    
        @thread_num.times do
            @inqueue.enq :END_OF_WORK
        end
        
        threads.each {|t| t.join}
        
        puts "Update Over"

    end
end
InsertJob.save_maven_errors