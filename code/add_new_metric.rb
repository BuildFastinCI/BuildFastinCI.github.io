require 'json'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'time_difference'
require 'activerecord-import'
require 'travis'
require 'rugged'
require 'thread'
#require_relative 'java'
require File.expand_path('../lib/repo_data_travis.rb',__FILE__)
require File.expand_path('../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../lib/commit_info.rb',__FILE__)
require File.expand_path('../lib/all_repo_data_virtual.rb',__FILE__)
#require File.expand_path('../commit_extract.rb',__FILE__)
require File.expand_path('../lib/temp_all_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../lib/loading.rb',__FILE__)
require File.expand_path('../lib/file_path.rb',__FILE__)
require File.expand_path('../lib/filemodif_info.rb',__FILE__)
require File.expand_path('../bin/diff_test.rb',__FILE__)
require File.expand_path('../lib/maven_error.rb',__FILE__)
require File.expand_path('../lib/job.rb',__FILE__)
require File.expand_path('../lib/travistorrents.rb',__FILE__)
require File.expand_path('../lib/travis_alldatas.rb',__FILE__)
require File.expand_path('../lib/travis_82_alldata.rb',__FILE__)
require File.expand_path('../lib/travis201701.rb',__FILE__)
require File.expand_path('../lib/travis_1027_alldatas.rb',__FILE__)

require File.expand_path('../lib/build_number.rb',__FILE__)
require_relative 'bin/java'
class AddNew
    include JavaData
  # @user = ARGV[0]
  # @repo = ARGV[1]
  # @parent_dir = File.join('build_logs/', "#{@user}@#{@repo}")
  
  def initialize(user,repo)
    @user=user
    @repo=repo
    @thread_number = 4
    @checkout_dir =File.expand_path(File.join('..','..','..','zc','sequence', 'repository',user+'@'+repo),File.dirname(__FILE__)) 
    
        #   repos = Rugged::Repository.new(checkout_dir)
    # @git = Rugged::Repository.new(@checkout_dir)
  end
  def init_update_test
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          info = @queue.deq
          break if info == :END_OF_WORK
          test_ok=nil
          test_fail=nil
          i=0
          puts "begin"
          Travistorrent_822017_alldatas.where("tr_build_id=?",info.build_id).find_all do |item|
            if !item.tr_log_num_tests_ok.nil? and item.tr_log_num_tests_ok!=''
                if !test_ok.nil?
                    test_ok+=item.tr_log_num_tests_ok.to_i
                else
                    test_ok=item.tr_log_num_tests_ok.to_i
                end
            end
            if !item.tr_log_num_tests_failed.nil? and item.tr_log_num_tests_failed!=''
                if !test_fail.nil?
                    test_fail+=item.tr_log_num_tests_failed.to_i
                else
                    test_fail=item.tr_log_num_tests_failed.to_i
                end
            end
            
            i=1
          end
          if i==0
            Travistorrent_11_1_2017datas.where("tr_build_id=?",info.build_id).find_all do |item|
                if !item.tr_log_num_tests_ok.nil? and item.tr_log_num_tests_ok!=''
                    if !test_ok.nil?
                        test_ok+=item.tr_log_num_tests_ok.to_i
                    else
                        test_ok=item.tr_log_num_tests_ok.to_i
                    end
                    
                end
                if !item.tr_log_num_tests_failed.nil? and item.tr_log_num_tests_failed!=''
                    if !test_fail.nil?
                        test_fail+=item.tr_log_num_tests_failed.to_i
                    else
                        test_fail=item.tr_log_num_tests_failed.to_i
                    end
                    
                end
                
                i=1
              end

          end
          if i==0
            Travistorrent_1027_alldatas.where("tr_build_id=?",info.build_id).find_all do |item|
                if !item.tr_tests_ok.nil? and item.tr_tests_ok!=''
                    if !test_ok.nil?
                        test_ok+=item.tr_tests_ok.to_i
                    else
                        test_ok=item.tr_tests_ok.to_i
                    end
                    
                end
                if !item.tr_tests_fail.nil? and item.tr_tests_fail!=''
                    if !test_fail.nil?
                        test_fail+=item.tr_tests_fail.to_i
                    else
                        test_fail=item.tr_tests_fail.to_i
                    end
                    
                end
                
                i=1
              end

          end
          if i==0
            Travistorrent_alldatas.where("tr_build_id=?",info.build_id).find_all do |item|
                if !item.tr_log_num_tests_ok.nil? and item.tr_log_num_tests_ok!=''
                    if !test_ok.nil?
                        test_ok+=item.tr_log_num_tests_ok.to_i
                    else
                        test_ok=item.tr_log_num_tests_ok.to_i
                    end
                    
                end
                if !item.tr_log_num_tests_failed.nil? and item.tr_log_num_tests_failed!=''
                    if !test_fail.nil?
                        test_fail+=item.tr_log_num_tests_failed.to_i
                    else
                        test_fail=item.tr_log_num_tests_failed.to_i
                    end
                    
                end
                
                i=1
            end
        end
          
          if i!=0 
            puts "====="
            info.tr_log_num_tests_ok=test_ok
            info.tr_log_num_tests_fail=test_fail
            info.save

          end
          
        end
        end
        threads << thread
      end

    threads
  end
  def update_test
    Thread.abort_on_exception = true
    threads = init_update_test
    info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        last_id=last_info.now_build_id
    All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=? and (tr_log_num_tests_ok is null or tr_log_num_tests_fail) is null ",first_id,last_id,"#{@user}@#{@repo}").find_all do |info|
    
        @queue.enq info
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "Update Over"
  end

  

 
  
  def error_type
        Thread.abort_on_exception = true
        threads = init_update_error_type
        All_repo_data_virtual_prior_merge.where("repo_name=? and last_label=0","#{@user}@#{@repo}").find_each do |info|
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "error_typeUpdate Over"
  end
  def init_update_error_type
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          info = @queue.deq
          break if info == :END_OF_WORK
          Maven_error.where("build_id=?",info.build_id).find_each do |item|
                if item.compliation==1 
                    info.pr_compile_error=1
               
                    
                    
                elsif !item.test_inerror.nil?
                    info.pr_test_exception=1
                    
                elsif !item.fail_test.nil?
                    info.pr_test_assert=1
                elsif item.dependency!=0
                    info.pr_depend_error=1
                else
                    info.pr_other_error=1
                    
                end
          end
          
          info.save
        end
        end
        threads << thread
      end
    threads   
  end
end



