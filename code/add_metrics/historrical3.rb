require_relative 'java'
require 'linguist'
require 'thread'
require 'rugged'
require 'json'
require 'fileutils'
require 'open-uri'
require 'net/http'
require 'activerecord-import'
require_relative 'java'
#require File.expand_path('../small_test.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../../lib/filemodif_info.rb',__FILE__)
require File.expand_path('../../lib/file_path.rb',__FILE__)
require File.expand_path('../../lib/cll_prevpass.rb',__FILE__)
require File.expand_path('../../bin/parse_html.rb',__FILE__)
require File.expand_path('../../lib/all_repo_data_virtual.rb',__FILE__)
require File.expand_path('../../lib/commit_info.rb',__FILE__)
require File.expand_path('../../lib/build.rb',__FILE__)
require File.expand_path('../../sola/get_modifiedlines.rb',__FILE__)
require File.expand_path('../../lib/cll_prevpass.rb',__FILE__)
require File.expand_path('../../lib/maven_error.rb',__FILE__)
require File.expand_path('../../lib/cll_prevfailcommit.rb',__FILE__)
require File.expand_path('../../lib/cll_prevpasscommit.rb',__FILE__)


class Historycal3
    def initialize(user,repo)
       
        @user=user
        @repo=repo
        @thread_num = 30
        
    end
    def last_fail
        Thread.abort_on_exception = true
        threads = init_last_fail
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        # All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=?","#{@user}@#{@repo}",last_id,first_id).find_each do |info|
           
        #     @queue.enq info
        # end
        All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=? and last_label=1 and (last_fail_gap_sum is null or last_fail_gap_sum =0)","#{@user}@#{@repo}",last_id,first_id).find_each do |info|
           
            @queue.enq info
        end
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "pr_src_files Update Over=========="
        return 
        
    end
    def init_last_fail
        
    
        @queue=SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
        thread = Thread.new do
            loop do
            info = @queue.deq
            break if info == :END_OF_WORK
            #   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
            if info.last_label==0
                info.last_fail_gap=1
                info.last_fail_gap_avg=1
                info.last_fail_gap_sum=1
                info.last_fail_gap_max=1
                info.save

            else
                item=Cll_prevfailcommit.where("git_commit=?",info.last_build_commit).order("insert_time desc").first
                next if item.nil?
                if !item.gap_num.nil? and item.gap_num.size!=0
                    info.last_fail_gap_avg=(item.gap_num.sum/item.gap_num.size).round(4)
                    info.last_fail_gap_sum=item.gap_num.sum
                    info.last_fail_gap_max=item.gap_num.max
                    info.save
                end
            end
            end
            end
            threads << thread
        end
        threads

    end

    def consec_fail_build
        Thread.abort_on_exception = true
        threads = init_consec_fail_build
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id

        # All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=?","#{@user}@#{@repo}",last_id,first_id).find_each do |info|
            
        #     @queue.enq info
        # end

        All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=? and last_label=0 and (consec_fail_builds_sum=0 or consec_fail_builds_sum is null )","#{@user}@#{@repo}",last_id,first_id).find_each do |info|
            
            @queue.enq info
        end
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "pr_src_files Update Over=========="
        return 
        
    end

    def init_consec_fail_build
        
    
        @queue=SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
        thread = Thread.new do
            loop do
            info = @queue.deq
            break if info == :END_OF_WORK
            #   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
            if info.last_label==1
                info.last_fail_gap=0
                info.consec_fail_builds_avg=0
                info.consec_fail_builds_sum=0
                info.consec_fail_builds_max=0
                info.save

            else
                item=Cll_prevpasscommit.where("git_commit=?",info.last_build_commit).order("insert_time desc").first
                next if item.nil?
                if !item.gap_num.nil? and item.gap_num.size!=0
                    info.consec_fail_builds_avg=(item.gap_num.sum/item.gap_num.size).round(4)
                    info.consec_fail_builds_sum=item.gap_num.sum
                    info.consec_fail_builds_max=item.gap_num.max
                    info.save

                else
                    fail_id=All_repo_data_virtual.where("commit=?",item.git_commit).first.build_id
                    last_passid=All_repo_data_virtual.where("commit=?",item.prev_passcommits.first).first.build_id
                    #补充完整
                    num=All_repo_data_virtual.where("build_id>=? and build_id<=? and repo_name=? and status in ('errored','failed')",last_passid,fail_id,"#{@user}@#{@repo}").count
                    info.consec_fail_builds_avg=num
                    info.consec_fail_builds_sum=num
                    info.consec_fail_builds_max=num
                    info.save
                end
            end
            end
            end
            threads << thread
        end
        threads

    end



    def pr_src_files_pass
        Thread.abort_on_exception = true
        threads = init_last_pass
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=? and last_label=1","#{@user}@#{@repo}",last_id,first_id).find_each do |info|
           
            @queue.enq info
        end
        @thread_num.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "pr_src_files Update Over=========="
        return 
        
    end
    def init_last_pass
        
    
        @queue=SizedQueue.new(@thread_num)
        threads=[]
        @thread_num.times do 
        thread = Thread.new do
            loop do
            info = @queue.deq
            break if info == :END_OF_WORK
            #   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
            # All_repo_data_virtual_prior_merge.where("now_build_id=?")
            info.pr_src_files=info.src_file
            info.pr_test_files=info.test_file
            info.pr_config_files=info.config_file
            info.pr_doc_files=info.txt_file
            info.pr_src_files_in=0
            info.pr_test_files_in=0
            info.pr_config_files_in=0
            info.pr_doc_files_in=0
            info.save

            end
            end
            threads << thread
        end
        threads

    end
end

