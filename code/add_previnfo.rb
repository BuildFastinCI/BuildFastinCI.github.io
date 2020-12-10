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
require File.expand_path('../lib/travis_1027_alldatas.rb',__FILE__)
require File.expand_path('../lib/build_number.rb',__FILE__)
require_relative 'bin/java'
module AddPrevinfo
    @thread_number=50
    def self.init_update_job_state
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
              line_added=0
              line_deleted=0
              file_added=0
              file_deleted=0
              
              All_repo_data_virtual_prior_merge.where("now_build_id=?",info.build_id).find_each do |item|
                    line_added+=item.line_added
                    line_deleted+=item.line_deleted
                    file_added+=item.file_added
                    file_deleted+=item.file_deleted
                    
              end
              info.prev_line_added=line_added
              info.prev_line_deleted=line_deleted
              info.prev_file_added=file_added
              info.prev_file_deleted=file_deleted
              
              info.save
              
              
            end
            end
            threads << thread
          end
    
        threads
      end
      
      
    
    
      def self.add_prev_info(user,repo)
        Thread.abort_on_exception = true
        threads = init_update_job_state
        @user=user
        @repo=repo
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").last
        last_id=last_info.now_build_id
        p last_id
        All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id>=? and now_build_id<=?","#{user}@#{repo}",first_id,last_id).find_all do |info|
        
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "prev info Update Over"
      end
    
    
end