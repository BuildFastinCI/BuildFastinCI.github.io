
require 'linguist'
require 'thread'
require 'rugged'
require 'json'
require 'fileutils'
require 'open-uri'
require 'net/http'
require 'activerecord-import'
require_relative 'java'
# require_relative 'java_log'

#require File.expand_path('../small_test.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../../lib/filemodif_info.rb',__FILE__)
require File.expand_path('../../lib/file_path.rb',__FILE__)
require File.expand_path('../../lib/cll_prevpass.rb',__FILE__)
# require File.expand_path('../../bin/parse_html.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual.rb',__FILE__)
require File.expand_path('../../lib/commit_info.rb',__FILE__)
require File.expand_path('../../lib/build.rb',__FILE__)
# require File.expand_path('../../sola/get_modifiedlines.rb',__FILE__)
require File.expand_path('../../lib/cll_prevpass.rb',__FILE__)
require File.expand_path('../../lib/maven_error.rb',__FILE__)

class HistoricalConnction2
    include JavaData
    # include JavaDatanew
    def initialize(user=0,repo=0)
       
            @user=user
            @repo=repo
            @thread_num = 20
            @text_file=["md","doc","docx","txt","csv","json","xlsx","xls","pdf","jpg","ico","png","jpeg","ppt","pptx","tiff","swf"]
       
    end


    def pr_src_files
        puts "pr_src_files=========="
        Thread.abort_on_exception = true
        threads = init_update_fail_build_rate
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        All_repo_data_virtual_prior_merge.where("repo_name=? and last_label=0 and now_build_id<=? and now_build_id>=?","#{@user}@#{@repo}",last_id,first_id).find_each do |info|
            
            @queue.enq info
        end
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "pr_src_files Update Over=========="
        return 
        
    end


    def init_update_fail_build_rate
        @queue=SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
              b=[]
              Cll_prevpassed.where("git_commit=?",info.last_build_commit).find_each do |item|
                b=b|item.filpath  

              end
              test_num=0
              txt_num=0
              src_num=0
              config_num=0
              for file_path in b do
                if JavaData::test_file_filter.call(file_path)
                    state = :in_test
                    test_num+=1
                  
                  elsif @text_file.include? file_path.strip.split('.')[1] 
                    state = :in_txt 
                    txt_num+=1 
                  elsif JavaData::src_file_filter.call(file_path)
                    state = :in_src
                    src_num+=1
                    # src_arry<< file_path.strip.split('a/',2)[1]
                  else 
                    state = :config
                    config_num+=1
                    
                  end
              end
              info.pr_src_files=src_num
              info.pr_test_files=test_num
              info.pr_config_files=config_num
              info.pr_doc_files=txt_num
              info.save 
              ActiveRecord::Base.clear_active_connections!
              end
            end
            threads << thread
          end
    
        threads
      end

      def pr_src_files_in
        puts "pr_src_files_in=========="
        ActiveRecord::Base.clear_active_connections! 
        Thread.abort_on_exception = true
        threads = init_src_files_in
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        commit_arry=[]
        All_repo_data_virtual_prior_merge.where("repo_name=? and last_label=0 and now_build_id<=? and now_build_id>=? and pr_file_flag=0","#{@user}@#{@repo}",last_id,first_id).find_each do |item|
            puts "==="
            commit_arry<< [item.last_build_commit,item.now_build_commit,item]
        end
        
        for commit in commit_arry do 
            b=[]
            file_info=File_path.where("last_build_commit=? and now_build_commit=?",commit[0],commit[1]).first 
            file_info=file_info.filpath
            Cll_prevpassed.where("git_commit=?",commit[0]).group("prev_passcommit").find_each do |item|
                b=b|item.filpath   
            end
            b
            # puts "commit[2]: #{commit[2]}, #{b}, #{file_info}"
            @inqueue.enq [commit[2],b,file_info]
        end
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "pr_src_files Update Over=========="
        return 
        
    end


    def init_src_files_in
        @inqueue = SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
                thread = Thread.new do
                    loop do
                    info = @inqueue.deq
                    break if info == :END_OF_WORK
                    
                    prev_matchfile info[0],info[1],info[2]
                    
                    
                    end
                end
                    threads << thread
                end
                threads
    end

    def prev_matchfile(id,filpath,file_prev)
    
   
        modif_num=0
        
        #filpath=item.filpath-[" ","","\\n"]
        if !filpath.empty? and !file_prev.empty?
            test_num=0
            txt_num=0
            src_num=0
            config_num=0
            touch_file=[]
            for tmps in filpath do
                
                if file_prev.size==0
                    break

                end
                #puts "tmps.class:#{tmps.class}"
                for value in file_prev do
                    
                    
                    #puts "value.class:#{value.class}"
                    if tmps.include? value or value.include? tmps
                       # item.error_modified=1
                       
                       touch_file << value
                       file_prev=file_prev-[value]
                       
                       puts file_prev.size
                       break
                        #puts "modif_num: #{modif_num}"
                    end    
                end
            end 
            for value in touch_file do
                if JavaData::test_file_filter.call(value)
                    state = :in_test
                    test_num+=1
                    break
                elsif @text_file.include? value.strip.split('.')[1] 
                    state = :in_txt 
                    txt_num+=1 
                    break
                elsif JavaData::src_file_filter.call(value)
                    state = :in_src
                    src_num+=1
                    break
                    # src_arry<< file_path.strip.split('a/',2)[1]
                else 
                    state = :config
                    config_num+=1
                    break
                    
                end
            end
            

                id.pr_src_files_in=src_num
                id.pr_test_files_in=test_num
                id.pr_config_files_in=config_num
                id.pr_doc_files_in=txt_num
                id.pr_file_flag=1
                id.save
            # end
        end
            
                
            
            ActiveRecord::Base.clear_active_connections!   
            
            #item.save
    end
    
    
    def log_src_files
        puts "==========log_src_files"
        Thread.abort_on_exception = true
        threads = init_log_src_files
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        All_repo_data_virtual_prior_merge.where("repo_name=? and last_label=0 and now_build_id<=? and now_build_id>=?","#{@user}@#{@repo}",last_id,first_id).find_each do |info|
        # All_repo_data_virtual_prior_merge.where("build_id=14192337").find_all do |info|   
            @inqueue.enq info
        end
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "pr_src_files Update Over=========="
        return 
        
    end

    def init_log_src_files
        @inqueue = SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
                thread = Thread.new do
                    loop do
                    info = @inqueue.deq
                    break if info == :END_OF_WORK
                   
                    test_num=0
                    txt_num=0
                    src_num=0
                    config_num=0
                    Maven_error.where("build_id=?",info.build_id).find_each do |item|
                        if !item.error_file.nil?
                            for file in item.error_file do
                                if @text_file.include? file.strip.split('.')[1] 
                                    state = :in_txt 
                                    txt_num+=1 
                                    
                                    next
                                elsif JavaData::filterlog.call(file)
                                    state = :in_test
                                    test_num+=1
                                    next
                                elsif JavaData::src_file_filter.call(file)
                                    state = :in_src
                                    src_num+=1
                                    next
                                    # src_arry<< file_path.strip.split('a/',2)[1]
                                else#xml文件和其他文件都是config 
                                    state = :config
                                    config_num+=1
                                    next
                                    
                                end
                            end
                        end
                    
                    
                    end
                    info.log_src_files=src_num
                    info.log_test_files=test_num
                    info.save
                end
                end
                    threads << thread
                end
                threads
    end

    def log_src_files_in
        puts "==========log_src_files_in"
        Thread.abort_on_exception = true
        threads = init_log_src_files_in
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        commit_arry=[]
        All_repo_data_virtual_prior_merge.where("repo_name=? and last_label=0 and now_build_id<=? and now_build_id>=? and log_file_flag=0","#{@user}@#{@repo}",last_id,first_id).find_each do |item|
            commit_arry<< [item.last_build_commit,item.now_build_commit,item,item.build_id]
        end
        
        for commit in commit_arry do 
            file_info=[]
            b=[]
            File_path.where("last_build_commit=? and now_build_commit=?",commit[0],commit[1]).find_all do |item|
                file_info=file_info|item.filpath
            end
            
            Maven_error.where("build_id=?",commit[3]).find_each do |item|
                b=b|item.error_file   
            end
            b
            # puts "commit[2]: #{commit[2]}, #{b}, #{file_info}"
            @inqueue.enq [commit[2],b,file_info]
        end
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "==========pr_src_files Update Over"
        return 
        
    end


    def init_log_src_files_in
        @inqueue = SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
                thread = Thread.new do
                    loop do
                    info = @inqueue.deq
                    break if info == :END_OF_WORK
                    matchfile info[0],info[1],info[2]
                    
                    
                    end
                end
                    threads << thread
                end
                threads
    end

    def matchfile(id,filpath,file_prev)
    
     #filpath log
     #file_prev file-path
        modif_num=0
        
        #filpath=item.filpath-[" ","","\\n"]
        if !filpath.empty? and !file_prev.empty?
            test_num=0
            txt_num=0
            src_num=0
            config_num=0
            for tmps in filpath do
                
                if file_prev.size==0
                    break
                end
                #puts "tmps.class:#{tmps.class}"
                for value in file_prev do
                    
                    
                    #puts "value.class:#{value.class}"
                    if tmps.include? value or value.include? tmps
                        file_prev=file_prev-[value]
                       # item.error_modified=1
                       if @text_file.include? value.strip.split('.')[1] 
                        state = :in_txt 
                        txt_num+=1 
                        
                        next
                        elsif JavaData::filterlog.call(value)
                            state = :in_test
                            test_num+=1
                            next
                        elsif JavaData::src_file_filter.call(value)
                            state = :in_src
                            src_num+=1
                            next
                            # src_arry<< file_path.strip.split('a/',2)[1]
                        else#xml文件和其他文件都是config 
                            state = :config
                            config_num+=1
                            next
                            
                        end
                        #puts "modif_num: #{modif_num}"
                        
                    end
                end 
            end
            # All_repo_data_virtual_prior_merge.where("id=?",id).find_each do |info|

                id.log_src_files_in=src_num
                id.log_test_files_in=test_num
                id.log_file_flag=1
                
                id.save
            # end
        end   
                
        
                
            
            #item.save
    end
    def test
        if JavaData::filterlog.call("")
            puts "yes test"

        else
            puts "no"
        end
    end
    

end
# xx=HistoricalConnction2.new("structr","structr")
# xx.log_src_files