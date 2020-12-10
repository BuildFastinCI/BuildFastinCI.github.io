require 'json'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'time_difference'
require 'activerecord-import'
require 'travis'
require 'rugged'
require 'travis'



require File.expand_path('../../lib/travis_torrent.rb',__FILE__)
require File.expand_path('../../lib/within_filepath.rb',__FILE__)
require File.expand_path('../../lib/travistorrents.rb',__FILE__)
require File.expand_path('../../lib/job.rb',__FILE__)
require File.expand_path('../download_job.rb',__FILE__)
require File.expand_path('../diff_within.rb',__FILE__)


MAVEN_ERROR_FLAG = /COMPILATION ERROR/
module WithinProjects
    @thread_num=40
    def self.prev_builtcommit(repo_name)
        Thread.abort_on_exception = true
        threads=init_prev_builtcommit
        puts repo_name
        Withinproject.where("id>0 and gh_project_name=?",repo_name).find_each do |info|
            
            @inqueue.enq info
        end
        @thread_num.times do
            @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end

    def self.init_prev_builtcommit
        @inqueue = SizedQueue.new(20)
        threads=[]
        @thread_num.times do 
        thread = Thread.new do
            loop do
            info = @inqueue.deq
            break if info == :END_OF_WORK
            #puts info
            split_commits info
            
            
            end
        end
            threads << thread
        end

        threads
        
    end

    def self.split_commits(info)
        if !info.git_commits.nil? or !info.git_commits.empty?
        info.pre_builtcommit=info.git_commits.split('#').last
        info.save
        ActiveRecord::Base.clear_active_connections!
        end

        
    end
    
    def self.init_update_job_number
        @queue=SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
          thread = Thread.new do
            loop do
              info= @queue.deq
              break if info == :END_OF_WORK
              jobs_arry=[]
              #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
               item=Job.where("job_id=?and repo_name=?",info.tr_job_id,info.gh_project_name ).first
                # job_num=Travis::Job.find(info.tr_job_id)
                # job_status=job_num.state
                if !item.nil?
                    info.job_number=item.job_number
                    info.job_status=item.job_state
                    info.save
                else
                    job_num=Travis::Job.find(info.tr_job_id)
                    info.job_status=job_num.state
                    info.job_number=job_num.number
                end
                info.save
                puts "======"
               
                ActiveRecord::Base.clear_active_connections!
      #highest_build = repository.last_build_number.to_i
     
              
              
              
              end
            end
            threads << thread
          end
    
        threads
      end
    
    
      
    def self.update_job_number(repo_name)
        #for last_status is nill
        Thread.abort_on_exception = true
        threads = init_update_job_number
        
        Withinproject.where("gh_project_name=?and job_number is  null",repo_name).find_all do |info|
        
        @queue.enq info
        end
   
                # jobs_arry=[]
                # #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
                # for job in info.jobs
                #   job_num=Travis::Job.find(job)
                #   jobs_arry << job_num.number
                # end

        #highest_build = repository.last_build_number.to_i
                # puts jobs_arry
                
        
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
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
    
    def self.compiler_error_message_slice(info,logpath)
        begin
        file_array = IO.readlines(logpath)
        rescue#不存在file
        #puts "begin"
        DownloadJobs.job_logs(logpath,info.tr_job_id)
            
            if File.exists?(logpath) and File.size(logpath) > 5
                file_array = IO.readlines(logpath)
            else
                puts "can not download"
                file_array=[]
            end
        ensure
            if file_array.size<2#null的情况
                DownloadJobs.job_logs(logpath,info.tr_job_id)
            
                if File.exists?(logpath) and File.size(logpath) > 5
                file_array = IO.readlines(logpath)
                else
                puts "can not download"
                file_array=[]
                end
            end
        
        end
        if file_array.size > 2
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
        
        mslice = maven_slice(file_array)
        #test_slice=test_maven_slice(file_array) #if log_hash[:maven]
        puts "MSLICE=========="
        
        '''
        #gslice = gradle_slice(file_array.reverse!) if log_hash[:gradle]
        
        # hash = Hash.new
        # hash[:repo_name] = log_hash[:repo_name]
        # hash[:job_number] = log_hash[:job_number]
        # hash[:job_id] = log_hash[:job_id]
        '''
        if mslice.length>0
            info.maven_slice = mslice
            
            info.error_type='1'
        end
        tmp_type=''
        failed_slice,test_error_slice=test_maven_slice(file_array)
        if failed_slice.length > 0
            info.fail_test=failed_slice
            if info.error_type=='0'
                info.error_type='2'
            else
                info.error_type=info.error_type+'2'
            end
            tmp_type=info.error_type
        end
        if test_error_slice.length>0
            info.test_inerror=test_error_slice
            unless tmp_type.include?'2'
                info.error_type=info.error_type+'2'
            end 
        
        end
        if info.error_type=='0'
            info.error_type='3'#other_error
        end
        info.save
        
    end
        
    end
    
    def self.init_save_maven_errors
        @inqueue = SizedQueue.new(30)
        threads=[]
        30.times do 
        thread = Thread.new do
            loop do
            
            arry = @inqueue.deq
            break if hash == :END_OF_WORK
            
            compiler_error_message_slice arry[0],arry[1]
            
            
            
            end
            end
            threads << thread
        end
    
        threads
    end
    
    def self.save_maven_errors(repo_name)
        Thread.abort_on_exception = true
        #threads = init_update_last_build_status2
        
        threads=init_save_maven_errors
        Withinproject.where("gh_project_name=? and job_status in ('errored','failed')",repo_name).find_all do |info|
        
        
        
        
        log_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', repo_name.sub(/\//, '@'), info.job_number.sub(/\./, '@')+'.log'), File.dirname(__FILE__))
        
        
        @inqueue.enq [info,log_path]
        end
        
    
        
        30.times do
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
    
    end
    
    def self.do_parse_file(info)
        file_arry=[]
            result=[]
            maven_file=[]
            if (!info.maven_slice.empty?)
                 
                #puts info.id
                maven_file=info.maven_slice[0].gsub(" ", "")
             
             
             result= maven_file.scan(/.*?\[ERROR?\](.*):[?\[]/)
             result=result.uniq
             if result.empty?
                result= maven_file.scan(/.*?\/(.*)[;]/)
             end
             for item in result
             file_arry << item[0]
             end
            end
            maven_file=[]
            result=[]
            result2=[]#记录warning
            result3=[]
            if (!info.test_inerror.empty?) 
                #puts info.test_inerror
                for line in info.test_inerror
                    
                    if line!=" " and line!="\n"
                       # puts line.gsub(" ","") 
                        maven_file<< line.gsub(" ","") 
                        #maven_file<< line.gsub(" "||"\\n", "")
                    end
                
                end
                maven_file=maven_file.join
                #puts maven_file
                result = maven_file.scan(/.*?\((.*)?\)[:]/)
                result2=maven_file.scan(/.*?foundin(.*)/)
                
                if result.include? '.'
                    result=result.uniq
                else
                    result=[]
                    
                end
                if result2.include? '.'
                    puts "include ."
                    result2=result2.uniq
                else
                    maven_file=maven_file.split("\n")
                    tmp=[]
                    for item in maven_file
                        #result2=item.scan(/.*?[\s\S]*?(.*?)[\.]/)
                        if item.include?'#'
                            puts"incude"
                            result2=item.scan(/.*?(.*?)[#]/)
                            #puts result2
                            if !result2[0].nil?
                                tmp<<result2[0]
                            end
                            
                        else
                            result2=item.scan(/.*?(.*?)[\.]/)
                            if !result2[0].nil?
                            tmp<<result2[0]
                            end
                        end
                        
                    end
                    result2=tmp.uniq
                end
                
                #result3=result3.uniq
                #嵌套的数组
                for item in result
                    file_arry << item[0].gsub(".","\/")
                end
                for item in result2
                    file_arry << item[0].gsub(".","\/")
                end
                # for item in result3
                #     file_arry << item[0]
                # end 
                #puts "file_arry here"
                #puts file_arry
            end 
            maven_file=[]
            result=[]  
            result2=[]
            if (!info.fail_test.empty?) 
                for line in info.fail_test
                    if line!=" "&&line!="\n"
                        maven_file << line.gsub(" "||"\\n", "")
                    end
                
                end
                maven_file=maven_file.join
                result = maven_file.scan(/.*?\((.*)?\)[:]/)
                result2=maven_file.scan(/.*?foundin(.*)/)
                if result.empty?
                    
                    result=maven_file.scan(/.*?\((.*)?\)/)
                end
                if result.include? '.'
                    result=result.uniq
                else
                    result=[]
                    
                end
                if result2.include? '.'
                    puts "include ."
                    result2=result2.uniq
                else
                    maven_file=maven_file.split("\n")
                    tmp=[]
                    for item in maven_file
                        #result2=item.scan(/.*?[\s\S]*?(.*?)[\.]/)
                        result2=item.scan(/.*?(.*?)[\.]/)
                        if !result2[0].nil?
                        tmp<<result2[0]
                        end
                    end
                    result2=tmp.uniq
                end
                result=result.uniq
                for item in result
                    file_arry << item[0].gsub(".","\/")
                end
                for item in result2
                    file_arry << item[0].gsub(".","\/")

                end
            end
            file_arry=file_arry.uniq
            if !file_arry.empty?
            info.error_file=file_arry
            info.save
            else
                info.error_file=nil
                info.save
            end
    end
    
    def self.init_parse_maven
        @inqueue = SizedQueue.new(@thread_num)
            threads=[]
            @thread_num.times do 
            thread = Thread.new do
                loop do
                info = @inqueue.deq
                break if info == :END_OF_WORK
                do_parse_file info
                
                
                end
            end
                threads << thread
            end
    
            threads
    end
    
    def self.parse_maven_error_file(repo_name)
        Thread.abort_on_exception = true
        threads=init_parse_maven   
        Withinproject.where("gh_project_name=? AND id=476 ",repo_name).find_all do |info|
            @inqueue.enq info
        end
        @thread_num.times do
            @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"         
        
    end
      


    def self.do_matchfile(info,filpath)
        
            modif_num=0
            
            #filpath=item.filpath-[" ","","\\n"]
            if !filpath.empty? and !info.error_file.empty?
                
                for tmps in filpath do
                    
                    
                    #puts "tmps.class:#{tmps.class}"
                    for value in info.error_file do
                        
                        
                        #puts "value.class:#{value.class}"
                        if tmps.include? value or value.include? tmps
                            info.error_modified=1
                            modif_num+=1
                            puts "modif_num: #{modif_num}"
                            break
                        end
                    end 
                end
                if modif_num>0
                    puts "=========#{modif_num}"
                info.modif_num=modif_num
                end
                info.save
            end
        
            
        
    end
    
    def self.init_update_errormodifiled
        @inqueue = SizedQueue.new(30)
        threads=[]
                30.times do 
                thread = Thread.new do
                    loop do
                    info = @inqueue.deq
                    break if info == :END_OF_WORK
                    do_matchfile info[0],info[1]
                    
                    
                    end
                end
                    threads << thread
                end
        
                threads
        
    end
    def self.update_errormodifiled(repo_name)
    
        Thread.abort_on_exception = true
        threads=init_update_errormodifiled 
        
        Withinproject.where("gh_project_name=? and job_status in('errored','failed')",repo_name).find_each do |info|
                 info.git_commit
        
        
        
            
            Within_filepath.where("prev_builtcommit=?", info.git_commit).find_each do |con|
               
            
            
                
                @inqueue.enq [info,con.filpath]
            end
            
            
        end
        
        30.times do
            @inqueue.enq :END_OF_WORK
        end
           
        threads.each {|t| t.join}
        puts "Update Over"  
        
    end



    def self.init_getable
        @inqueue = SizedQueue.new(30)
        threads=[]
                30.times do 
                thread = Thread.new do
                    loop do
                    info = @inqueue.deq
                    break if info == :END_OF_WORK
                    
                    item=Withinproject.where("git_commit=?",info.pre_builtcommit).group("bl_cluster").all
                    first_item=Withinproject.where("git_commit=?",info.pre_builtcommit).group("bl_cluster").first
                    puts "------"
                    next if item.nil?
                        if item.tr_status=='passed'
                            info.prev_tr_status=1
                        else
                            info.prev_tr_status=0
                        end
                        if !item.bl_cluster.nil?#数据库为空
                            num=item.size
                            cluster=0
                            item.find_each do |tmp|
                                cluster+=
                                info.prev_bl_cluster=item.bl_cluster.delete('mvncl').to_i

                            end
                        end
                        info.prev_gh_src_churn=item.gh_src_churn
                        info.prev_gh_test_churn=item.gh_test_churn
                        info.save
                      
                        ActiveRecord::Base.clear_active_connections!
                    
                    
                    end
                end
                    threads << thread
                end
        
                threads
        
    end


    def self.get_table(repo_name)
        Thread.abort_on_exception = true
        threads=init_getable 
        Withinproject.where("gh_project_name=? AND prev_tr_status is null",repo_name).find_each do |info|
            @inqueue.enq info
            
           
        end
        30.times do
            @inqueue.enq :END_OF_WORK
        end
           
        threads.each {|t| t.join}
        puts "Update Over"  

    end

    def self.init_getallpj
        @queue = SizedQueue.new(@thread_num)
        threads=[]
                @thread_num.times do 
                thread = Thread.new do
                    loop do
                    info = @queue.deq
                    break if info == :END_OF_WORK
                    builds=[]
                    Travistorrent.select("id,row_num,git_commit, tr_build_id, gh_project_name, gh_is_pr, git_merged_with, gh_lang, git_branch, gh_first_commit_created_at, gh_team_size, git_commits, git_num_commits,tr_prev_build, gh_num_issue_comments, gh_num_commit_comments, gh_num_pr_comments, gh_src_churn, gh_test_churn, gh_files_added, gh_files_deleted, gh_files_modified, gh_tests_added, gh_tests_deleted, gh_src_files, gh_doc_files, gh_other_files, gh_commits_on_files_touched, gh_sloc, gh_test_lines_per_kloc, gh_test_cases_per_kloc, gh_asserts_cases_per_kloc, gh_by_core_team_member, gh_description_complexity, gh_pull_req_num, tr_duration, tr_started_at, tr_jobs, tr_build_number, tr_job_id, tr_lan, tr_setup_time, tr_analyzer, tr_tests_ok, tr_tests_fail, tr_tests_run, tr_tests_skipped, tr_failed_tests, tr_testduration, tr_purebuildduration, tr_tests_ran, tr_tests_failed, git_num_committers, tr_num_jobs, bl_log, bl_cluster, cmt_importchangecount, cmt_classchangecount, cmt_methodchangecount, cmt_fieldchangecount, cmt_methodbodychangecount, cmt_buildfilechangecount").where("gh_project_name=? and tr_analyzer='java-maven' and gh_lang='java'",info).find_each do |item|
                        hash=item.attributes.deep_symbolize_keys
                        hash.delete(:id)
                        test=Withinproject.new(hash)
                        test.save 
                        puts '======='
                        ActiveRecord::Base.clear_active_connections!
                    end
                    # puts "========="
                    # Withinproject.import builds,validate: false
                    
                    end
                end
                    threads << thread
                end
        
                threads
        
    end


    def self.get_allpj
        Thread.abort_on_exception = true       
        threads = init_getallpj        
        Travistorrent.find_by_sql("SELECT gh_project_name FROM travistorrents where  tr_analyzer='java-maven' and gh_lang='java' and gh_project_name<>'structr/structr'  group by gh_project_name having count(*)>=1000").find_all do |info|
        #puts info
        #diff_arry<<info.duration
        #build= info.attributes.deep_symbolize_keys
        puts info.gh_project_name
        @queue.enq info.gh_project_name
        end
        
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
    end
#===========================================================
    def self.update_fail_build_rate(user,repo)
        #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
        puts "in here"
        Thread.abort_on_exception = true
        threads = init_update_fail_build_rate
        All_repo_data_virtual_prior_merge.where("id>? and repo_name=?",0,"#{user}@#{repo}").find_each do |info|
        
        reponame="#{user}@#{repo}"
        @queue.enq [info,reponame]
        end
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
          # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
          # info.fail_build_rate=format("%.3f",Float(m)/c)
          # info.save
    
      end 
    
      def self. init_update_fail_build_rate
        @queue=SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
          thread = Thread.new do
            loop do
              arry = @queue.deq
              break if arry == :END_OF_WORK
              m=Repo_data_travi.where("build_id< ? and repo_name=? ",arry[0][:build_id],arry[1]).find_each.size
              c=Repo_data_travi.where("build_id< ? and repo_name=? and status not in ('passed','canceled')",arry[0][:build_id],arry[1]).find_each.size
              if m!=0
                arry[0].fail_build_rate=format("%.3f",Float(c)/m)
                arry[0].save
              end
              ActiveRecord::Base.clear_active_connections!
              end
            end
            threads << thread
          end
    
        threads
      end
#=================================================
def self.init_prev_pass
    @queue = SizedQueue.new(@thread_num)
    threads=[]
            @thread_num.times do 
            thread = Thread.new do
                loop do
                info = @queue.deq
                break if info == :END_OF_WORK
                builds=[]
                item=Travistorrent.where("git_commit=?",info.pre_builtcommit).first
                while item.tr_status!='passed' and !item.nil?
                    tmp=item
                    item=Withinproject.where("git_commit=?",item.git_commits.split('#').last).first
                    
                end
                if !item.nil?
                    user=info.gh_project_name.split('/').first
                    repo=info.gh_project_name.split('/').last
                    DiffWithin.test_diff(user,repo,item.git_commit,info,2)
                else
                    while tmp.tr_status!='passed' and !tmp.nil?
                        
                        tmp=Travistorrent.where("git_commit=?",item.git_commits.split('#').last).first
                        
                    end
                    if
                        if !tmp.nil?
                            user=info.gh_project_name.split('/').first
                            repo=info.gh_project_name.split('/').last
                            DiffWithin.test_diff(user,repo,tmp.git_commit,info,2)
                        end

                    end


                end
                    #ActiveRecord::Base.clear_active_connections!
                
                # puts "========="
                # Withinproject.import builds,validate: false
                
                end
            end
                threads << thread
            end
    
            threads
    
end



    def self.prev_pass(repo_name)
        Thread.abort_on_exception = true
        threads = init_prev_pass
        Withinproject.where("id>? and gh_project_name=? and tr_status<>'passed'",0,repo_name).group("git_commit").find_each do |info|
        
       
        @queue.enq info
        end
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end   
     
    


    def self.run(repo_name)
        #prev_builtcommit(repo_name)
        update_job_number(repo_name)
        #save_maven_errors(repo_name)
        #prev_pass(repo_name)
        #parse_maven_error_file(repo_name)
        #update_errormodifiled(repo_name)
        #get_table(repo_name)
        #get_allpj
        
    end


    def self.init_allocate
        @inqueue = SizedQueue.new(@thread_num)
        threads=[]
                @thread_num.times do 
                thread = Thread.new do
                    loop do
                    info = @inqueue.deq
                    break if info == :END_OF_WORK
                    run info
                    # puts "========="
                    # Withinproject.import builds,validate: false
                    
                    end
                end
                    threads << thread
                end
                threads       
    end



    def self.allocate
        Thread.abort_on_exception = true
        
        
        threads = init_allocate
        
        Withinproject.where("id>0").group("gh_project_name").find_all do |info|
        #puts info
        #diff_arry<<info.duration
        #build= info.attributes.deep_symbolize_keys
        
        @inqueue.enq info.gh_project_name
        end
        
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end

    def self.method_name
        #run 'structr/structr'

        Withinproject.where("id>0").group("gh_project_name").find_all do |info|
            #puts info
            #diff_arry<<info.duration
            #build= info.attributes.deep_symbolize_keys
            
            run info.gh_project_name
            #break
            end
        
    end
end
repo_name=ARGV[0]
WithinProjects.method_name