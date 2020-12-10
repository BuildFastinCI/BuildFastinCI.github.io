require 'time'
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
class CurrentBuild
    
    def initialize(user,repo)
        @user=user
        @repo=repo
        @thread_number = 40
      checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository',user+'@'+repo),File.dirname(__FILE__)) 
          #   repos = Rugged::Repository.new(checkout_dir)
      @git = Rugged::Repository.new(checkout_dir)
    end

    def now_is_pr
        Thread.abort_on_exception = true
        threads = init_update_pr
        puts "is_pr"
        All_repo_data_virtual_prior_merge.where("now_is_pr =0").find_each do |item|
            @queue.enq item

        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end
    def init_update_pr
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
              test_ok=0
              test_fail=0
              i=0
              tmp=All_repo_data_virtual.where("build_id=?",info.now_build_id).first
              if !tmp.pull_req.nil?
                 info.now_is_pr=1
                 info.save
              end
              
            end
            end
            threads << thread
        end
        threads
      end
      

    def pr_comment
        Thread.abort_on_exception = true
        threads = init_update_comment
        puts "pr_comment"
        puts "#{@user}@#{@repo}"
        All_repo_data_virtual_prior_merge.where("pr_comments=0 and repo_name=? and now_is_pr=1", "#{@user}@#{@repo}").find_each do |item|
            
            @queue.enq item
            
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end
    def init_update_comment
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
              checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
                             
            begin
                if File.exists?(checkout_dir) and File.size(checkout_dir) > 5
                    commitinfo = GetModifiedLine.load_all_builds(checkout_dir)
                    
                    info.pr_comments= commitinfo["commit"]["comment_count"]
                else#不存在file
                    
                    
                    parent_dir = File.join('commits', @user+'@'+@repo)
                    commit_json = File.join(parent_dir, "#{info.now_build_commit}.json")
                #   checkout_dir=File.join('commits',repo_name.split('/')[0]+'@'+repo_name.split('/')[1],commit+'.json')
                #   .job_logs(log_hash[:log_path],log_hash[:job_id])
                    
                    if File.exists?(commit_json) and File.size(commit_json) > 5
                        
                        
                        commitinfo = GetModifiedLine.load_all_builds(commit_json)
                        info.pr_comments =  commitinfo["commit"]["comment_count"]
                        
                    else
                        
                        commitinfo = ParseHtml.github_commit(@user, @repo, info.now_build_commit,0)
                        
                        if !commitinfo.nil? or !commitinfo.empty?
                         info.pr_comments =  commitinfo["commit"]["comment_count"]
                        end
                    end

                end   
            end
                        
              info.save
            end
            end
            threads << thread
        end
        threads
      end

      def pr_fix_mergecommit
        Thread.abort_on_exception = true
        threads = init_fix_mergecommit
        puts "pr_fix_mergecommit"
        puts "#{@user}@#{@repo}"
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        last_id=last_info.now_build_id
        All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=? ",first_id,last_id,"#{@user}@#{@repo}").find_all do |info|
        
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end
    def init_fix_mergecommit
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
            #   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
              fix_commit=0
              merge_commit=0              
              for commit in info.commit_list do
                item=Commit_info.where("commit=? and close_fixed_resolved is not null",commit)
                if item.count==0
                    item=Commit_info.where("commit=? and merge_flag is not null",commit)
                    if item.count!=0
                        merge_commit+=1  
                    end
                else
                    fix_commit+=1
                end
              end         
              info.fix_commits=fix_commit
              info.merge_commits=merge_commit
              info.save
            end
            end
            threads << thread
        end
        threads
      end


      def pr_description
        Thread.abort_on_exception = true
        threads = init_description
        puts "description"
        puts "#{@user}@#{@repo}"
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        last_id=last_info.now_build_id
        All_repo_data_virtual_prior_merge.where("repo_name=? and now_is_pr=1 ","#{@user}@#{@repo}").find_all do |info|
        
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end
    def init_description
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
            #   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
            nword=0
            Build.where("tr_build_id=?",info.now_build_id).find_each do |item|
            
                item.pull_request_title.each_line do |line|
                  words = line.split(/\s+/).reject{|w| w.empty? }
                  
                  nword += words.length
                  
                end
            end
              info.pr_description=nword
              info.save
            end
            end
            threads << thread
        end
        threads
      end

    def time_day
        Thread.abort_on_exception = true
        threads = init_time_day
        puts "description"
        puts "#{@user}@#{@repo}"
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        last_id=last_info.now_build_id
        All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=? and time_of_day is null","#{@user}@#{@repo}",last_id,first_id).find_all do |info|
        
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end
    def init_time_day
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
              if !info.now_start_at.nil?
                puts "=="
                hour=info.now_start_at.hour
                info.time_of_day=hour
                info.save
              end
            #   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
              
            end
            end
            threads << thread
        end
        threads
      end





      def commits_on_build_files(owner, repo, build, months_back)

        oldest = Time.at(build[:now_started_at].to_i - 3600 * 24 * 30 * months_back)
        # puts build[:commit_list]
        commits = commit_entries(owner, repo, build[:commit_list])
    
        commits_per_file = commits.flat_map { |c|
          c['files'].map { |f|
            [c['sha'], f['filename']]
          }
        }.group_by { |c|
          c[1]
        }
       begin
        commits_per_file.keys.reduce({}) do |acc, filename|
            commits_in_pr = commits_per_file[filename].map { |x| x[0] }
           
              walker = Rugged::Walker.new(@git)
              walker.sorting(Rugged::SORT_DATE)
              walker.push(build[:now_build_commit])
          
              commit_list = walker.take_while do |c|
                  c.time > oldest
              end.reduce([]) do |acc1, c|
                  if c.diff(paths: [filename.to_s]).size > 0 and
                      not commits_in_pr.include? c.oid
                  acc1 << c.oid
                  end
                  acc1
              end
              acc.merge({filename => commit_list})
                
            
            
          end
           
       rescue => exception
           nil
       end
        
      end

      def commit_entries(owner, repo,commits)
        if commits.is_a? Array
          commit_new=commits.pop
        else
          commits=[commits]
        end
        
        commit_entry=[]
        for commit in commits do
            checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+commit+'.txt'),File.dirname(__FILE__))
            
            begin
                if File.exists?(checkout_dir) and File.size(checkout_dir) > 5
                    commitinfo = GetModifiedLine.load_all_builds(checkout_dir)
                    
                    
                else#不存在file
                    
                    
                    parent_dir = File.join('commits', @user+'@'+@repo)
                    commit_json = File.join(parent_dir, "#{commit}.json")
                #   checkout_dir=File.join('commits',repo_name.split('/')[0]+'@'+repo_name.split('/')[1],commit+'.json')
                #   .job_logs(log_hash[:log_path],log_hash[:job_id])
                    
                    if File.exists?(commit_json) and File.size(commit_json) > 5
                        
                        
                        commitinfo = GetModifiedLine.load_all_builds(commit_json)
                        
                        
                    else
                        
                        commitinfo = ParseHtml.github_commit(@user, @repo, commit,0)
                        
                        
                    end
        
                end 
                if !commitinfo.nil? or !commitinfo.empty?
                    commit_entry << commitinfo
                end

            end
        end
        return commit_entry
                    
      end
      # Number of unique commits on the files changed by the build commits
      # between the time the build was created and `months_back`
      def commits_on_files_touched(owner, repo,build , months_back)
        begin
            commits_on_build_files(owner, repo, build, months_back).reduce([]) do |acc, commit_list|
                acc + commit_list[1]
              end.flatten.uniq.size
            
        rescue => exception
            nil
        end
       
      end

      
      def  commmit_on_file
            Thread.abort_on_exception = true
            threads = init_commmit_on_file
            puts "description"
            puts "#{@user}@#{@repo}"
            info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
            first_id=info.now_build_id
            last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
            last_id=last_info.now_build_id
            All_repo_data_virtual_prior_merge.where("repo_name=? and commits_on_files =0 and commit_file_flag=0 ","#{@user}@#{@repo}").find_all do |info|
            
                @queue.enq info
            end
            @thread_number.times do   
            @queue.enq :END_OF_WORK
            end
            threads.each {|t| t.join}
            puts "Update Over"
          
      end
      def init_commmit_on_file
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
            #   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'data',@user+'@'+@repo,'singlecommit_'+info.now_build_commit+'.txt'),File.dirname(__FILE__))
               num=commits_on_files_touched(@user,@repo,info,3)
               if  num.nil?
                info.commit_file_flag=1
               end
               info.commits_on_files=num
               info.save
               
            end
            end
            threads << thread
        end
        threads
      end

      def self.run
        All_repo_data_virtual_prior_merge.where("id > ?", 0).find_each do |build|
          p build.id
          count = 0 #计算该指标取值
          repo_name = build.repo_name
          #取本次build变更文件列表
          current_files = []
          dt = nil # 取最小commit时间
          build.commit_list.each do |sha|
            ci = CommitInfo.find_by(commit: sha)
            dt = ci.commit_date if dt.nil? || dt > ci.commit_date
            next if ci.nil?
            ci.commit_files.each { |cf| current_files << cf.file_name }
          end
          current_files.uniq!
          next if current_files.length == 0
          p current_files
          CommitInfo.where("repo_name = ? AND commit_date < ? AND commit_date >= DATE_SUB(?, INTERVAL 90 DAY)", repo_name, dt, dt).find_each do |tci|
            t_files = []
            tci.commit_files.each { |cf| t_files << cf.file_name }
            intersection = current_files & t_files #取两个数组交集
            count += 1 if intersection.length > 0
          end
          p count
          #build.commit_on_files = count
          #build.save
        end
      end
       
    
end


# cur=CurrentBuild.new("structr","structr")
# item=All_repo_data_virtual_prior_merge.where("repo_name=? and id=192135 ","structr@structr").first
            
   
# p cur.commits_on_files_touched("structr","structr",item,3)