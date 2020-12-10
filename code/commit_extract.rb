

require 'time'
require 'linguist'
require 'thread'
require 'rugged'
require 'json'
require 'open-uri'
require 'net/http'
require 'fileutils'
require 'time_difference'
require 'activerecord-import'
#require_relative 'java'
require File.expand_path('../lib/repo_data_travis.rb',__FILE__)
require File.expand_path('../lib/commit_info.rb',__FILE__)
require File.expand_path('../lib/all_repo_data_virtual.rb',__FILE__)
require File.expand_path('../bin/parse_html.rb',__FILE__)
require File.expand_path('../fix_sql.rb',__FILE__)

  
  @out_queue = SizedQueue.new(2000)
  @local_miss_commit=[]
  
  $global_arry=[]
  $author_arry=[]
  $build_stats=[]
  @thread_num=30
  puts "@parent_dir"
  puts @parent_dir
 
  $token = [
    "3f5cd6ea063da76429c2ac7616bb4061fe94477b",#我
    "eecd9fbfe794668811c673f252fc96a01f4e378f",#小白
    "047a47a4f6cf125e4ef9f095c5afa6419b4bc292",#xue
    "7d796d2bfca8ab9766dea7d0a4bcf5987609a391",#学弟
    "dc6fa8c5a0fd1c513f13ed1e23d3323ff21fc616",
    "0301031709c2b4ecfea9b9cd2751a38da83e6676",#wo
  ]
  @threads_number = $token.size * 2
  $REQ_LIMIT = 4990
  $id=0
  
  def load_all_builds(rootdir,filename)
    f = File.join(rootdir, filename)
    unless File.exists? f
      puts "不能找到"
      return {}
    end

    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
  end

  def load_builds(owner, repo)
    f = File.join("build_logs", "#{owner}@#{@repo}", "repo-data-travis.json")
    unless File.exists? f
      puts "不能找到"
    end

    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
  end


  def load_commit(owner, repo)
     f = File.join("build_logs", "#{owner}@#{@repo}", "commits_info.json")
    unless File.exists? f
      puts "不能找到"
    end

    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
  end


  def is_pr?(build)
    # puts "build_id #{build[:build_id]}"
    build[:pull_req].nil? ? false : true
  end

  def write_file(contents,parent_dir,filename)
    json_file = File.join(parent_dir, filename)
    if contents.class == Array
      
        contents.flatten!
    # Remove empty entries
        #contents.reject! { |c| c.empty? }
    end
    if File.exists? json_file
      #puts "all_commit:#{all_commits}"
      
    
      
    # Remove empty entries
      
      puts "initial builds size #{contents.size}"
      if contents.empty?
        error_message = "Error could not get any repo information for #{parent_dir}."
        puts error_message    
        
      end
    
      File.open(json_file, 'w') do |f|
      f.puts JSON.dump(contents)
      end
    
     else
      File.open(json_file, 'w') do |f|
      f.puts JSON.dump(contents)
      end
    end

      
  end

  def write_file_add(contents,parent_dir,filename)
    json_file = File.join(parent_dir, filename)
    if contents.class == Array
      
        contents.flatten!
    # Remove empty entries
        contents.reject! { |c| c.empty? }
    end
    if File.exists? json_file
      #puts "all_commit:#{all_commits}"
      
    
      
    # Remove empty entries
      
      #puts "initial builds size #{contents.size}"
      if contents.empty?
        error_message = "Error could not get any repo information for #{parent_dir}."
        puts error_message    
        exit(1)
      end
    
      File.open(json_file, 'a') do |f|
      f.puts(JSON.dump(contents)) 
      end
    
    else
      File.open(json_file, 'a') do |f|
      f.puts JSON.dump(contents)
      end
    end

      
  end

  def clonein(user,repo1)
    #checkout_dir = File.join('repos', user, repo1)
    def spawn(cmd)
      proc = IO.popen(cmd, 'r')

      proc_out = Thread.new {
        while !proc.eof
          puts  "GIT: #{proc.gets}"
        end
      }

      proc_out.join
    end
    checkout_dir =File.expand_path(File.join('..','..','sequence', 'repository', user+'@'+ repo1),File.dirname(__FILE__)) 
    #checkout_dir = File.expand_path(File.join('..', '..', '..', 'sequence', 'repository',user+'@'+'repo1'), File.dirname(__FILE__))
    
    
    begin
      puts "checkoout_dir rugged #{checkout_dir}"
      repo = Rugged::Repository.new(checkout_dir)
      unless repo.bare?
        puts "not bare"
        spawn("cd #{checkout_dir} && git pull")
      end
      repo
      
      
    rescue
      spawn("git clone git://github.com/#{user}/#{repo1}.git #{checkout_dir}")
      #repo = Rugged::Repository.new(checkout_dir)
    end  
    
  end

  def process(user,repo1)
    
      ActiveRecord::Base.clear_active_connections!
      if Repo_data_travi.where('repo_name=?',"#{user}@#{repo1}").count>1
        puts "have repo_data_travis already"
        commitinfo(user,repo1)
      else
        builds = load_builds(user, repo1)
        puts user+'@'+repo1
        puts "initial_builds.size #{builds.size}"
        #repo_data=Repo_data_travi.new
        builds = builds.reduce([]) do |acc, b|
          unless b[:started_at].nil?
            #b[:started_at] = Time.parse(b[:started_at])
            acc << b
          else
            acc
          end
        end
        puts "After filtering empty build dates: #{builds.size} builds"
        
        builds.each do |a|

          a[:repo_name]="#{user}@#{repo1}"
          
          
        end
        builds = builds.group_by { |x| x[:build_id] }.map { |k, v| v[0] }
        puts "After filtering duplicate build_id: #{builds.size} builds"
        write_file(builds,@parent_dir,"repo-data-travis.json")
        ActiveRecord::Base.clear_active_connections!
        begin
          Repo_data_travi.import builds,validate: false
          puts 'Repo_data_travis update over'
        rescue
          
        ensure
          commitinfo(user,repo1)
        end

      end
      
      # puts 'Repo_data_travis update over'
      # commitinfo(user,repo1)
  end

  def commitinfo(user,repo1)
    if Commit_info.where('repo_name=?',"#{user}@#{repo1}").count>1
        clonein(user,repo1)
        puts "have commit_info already"
        found_vcommit(user,repo1)
    else
      clonein(user,repo1)
      builds = load_builds(user, repo1)
      checkout_dir =File.expand_path(File.join('..','..','sequence', 'repository', user+'@'+ repo1),File.dirname(__FILE__)) 
      repo = Rugged::Repository.new(checkout_dir)
      walker = Rugged::Walker.new(repo)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(repo.head.target)
      puts repo.head.target
      
      all_commit = Hash.new
      all_commits = []
      walker.map do |commit|
        
        #puts commit.parent_ids
        begin
           all_commit={
             :repo_name=>"#{user}@#{repo1}",
             :commit => commit.oid,
             :message => commit.message,
             :commit_parents => commit.parent_ids,
             :committer_email => commit.committer[:email],
             :commit_started_at => commit.time
           }
          
        rescue
          puts "no commit info"
        end
        all_commits << all_commit
      end
      @parent_dir = File.join('build_logs/',  "#{user}@#{repo1}")
      json_file = File.join(@parent_dir, 'commits_info.json')
      #puts "all_commit:#{all_commits}"
      all_commits.flatten!
      # Remove empty entries
      all_commits.reject! { |c| c.empty? }
      # Remove duplicates
      all_commits = all_commits.group_by { |x| x[:commit] }.map { |k, v| v[0] }
      puts "initial builds size #{builds.size}"
      if all_commits.empty?
        error_message = "Error could not get any repo information for #{repo1}."
        puts error_message    
        exit(1)
      end 
      #puts all_commits
      for icommit in all_commits
        icommit[:repo_name] = "#{user}@#{repo1}"
        icommit[:message]=icommit[:message].force_encoding('ISO-8859-1')
      end
      File.open(json_file, 'w') do |f|
      f.puts JSON.dump(all_commits)
      end
      #读取所有commit信息
      
      #all_commit=load_commit(user,repo1)
      # puts builds.class
      # acc=Array.new
      # all_commit=all_commits.each do |commit|
      #   commit[:message]=commit[:message].force_encoding('ISO-8859-1')
      # end
      all_commit=all_commits.dup
      fixre = /(?:fixe[sd]?|close[sd]?|resolve[sd]?)(?:[^\/]*?|and)#([0-9]+)/mi
      
      #puts  'Calculating PRs closed by commits'
          
      closed_by_commit =
          all_commit.map do |x|
              sha = x[:commit]
              result = {}
           
              comment = x[:message]

              comment.match(fixre) do |m|
                temparr=m[0][0..10]
                temparr=temparr.split(" ")
                (1..(m.size - 1)).map do |y|
                  result[m[y].to_i] = sha+"#"+temparr[0]#close/fixed/resolved  {issue_id,pr_id=>"sha"}
                end
              end
              if !result.empty?
                name=result[result.keys[0]].split("#")[1]
                x[:close_fixed_resolved ]= (result.keys[0]).to_s+"#"+name
                puts  x[:close_fixed_resolved ]
                #puts x
              else
                x[:close_fixed_resolved ]=nil
              end 

              result
          end.select { |m| !m.empty? }.reduce({}) { |x, m| x.merge(m) }
      puts "#{closed_by_commit.size} PRs closed by commits"
      ActiveRecord::Base.clear_active_connections!
      #puts closed_by_commit
      # begin
        Commit_info.import all_commit
        puts "commit_info inserted"
        puts "Retrieving commits that were actually built (for pull requests)"
      # rescue
      #   Commit_info.import all_commit
      #   puts "commit_info inserted"
      #   puts "Retrieving commits that were actually built (for pull requests)"
      # ensure
        found_vcommit(user,repo1)
      # end
    end
      
  end

  def init_find_vcommit
    puts 'find_vcommit'
    # begin
    # local_norecord=IO.readlines("build_logs/#{@user}@#{@repo}/no_record_commit.json")
    # local_no_record=[]
    # local_norecord.each do |line|
    #   local_no_record << JSON.parse(line)
    # end 
    # rescue
    #   local_no_record=[]
    # end
    ActiveRecord::Base.clear_active_connections!
    $no_record_commit=[]
    mutex = Mutex.new
    @queue = SizedQueue.new(@thread_num)
        threads=[]
        i=0
                @thread_num.times do 
                thread = Thread.new do
                    loop do
                    if i>=0
                      
                      build = @queue.deq
                      break if build == :END_OF_WORK
                      if is_pr?(build)
                        k=i%($token.size)
                        i=i+1
                        if Commit_info.where("commit=?",build[:commit]).find_each.size!=0
                          Commit_info.where("commit=?",build[:commit]).find_each do |commit_info|
                            shas=commit_info[:message].match(/Merge (.*) into (.*)/i).captures
                            
                          end
                          puts 'commit_info有'
                          ActiveRecord::Base.clear_active_connections!
                        else
                          #lost_commit<< build[:commit]
                          #hash = Hash[user: user,repo:repo1, sha: build[:commit]]
                          #@queue.enq hash
                        #判断是这个COMMIT是否是不存在的
                          # if local_no_record.include? build[:commit]
                          #   next
                            
                          # end
                          puts "API find"
                          
                          c = ParseHtml.github_commit(@user, @repo, build[:commit],k)
                          unless c.empty? || c.nil?
                            shas = c['commit']['message'].match(/Merge (.*) into (.*)/i).captures
                          else
                            nil
                            puts "API-GITHUB 获取失败"
                            mutex.lock
                            #no_record_commit << build[:commit]
                            write_file_add(build[:commit],@parent_dir,"no_record_commit.json")
                            mutex.unlock
                            #需要删掉build?
                          end
                          
                        end
                        if !shas.nil?
                          if shas.size == 2
                            puts "Replacing Travis commit #{build[:commit]} with actual #{shas[0]}"
                            #build[:commit]=
                            build[:merge_commit] = build[:commit]
                            build[:commit]=shas[0]
                            build[:tr_virtual_merged_into] = shas[1]
                            
                            $builds << build
                            mutex.lock
                            
                            write_file_add(build,@parent_dir,"repo-data-virtual-travis.json")
                            mutex.unlock
                          else
                            build[:merge_commit] = nil
                  
                            build[:tr_virtual_merged_into] = nil
                            $builds << build
                          end
                        else
                          
                          build[:merge_commit] = nil
                  
                          build[:tr_virtual_merged_into] = nil
                          $builds << build
                          next
                        end
                        build
                        
                      else 
                        #build
                        build[:merge_commit] = nil
                        build[:tr_virtual_merged_into] = nil
                        $builds << build
                      end
                    # puts "========="
                    # Withinproject.import builds,validate: false
                  end
                    end
                end
                    threads << thread
                end
        
                threads
        
    
  end

  def found_vcommit(user,repo)
    if All_repo_data_virtual.where('repo_name=?',"#{user}@#{repo}").count>1
      FixSql.process_dup(user,repo)
      ActiveRecord::Base.clear_active_connections!
    #FixSql.process_dup2(user,repo)
      puts "dup1 clear"
      build_state_threads(user,repo)
    else
      lost_commit=[]
      $no_record_commit=[]
      $builds=[]
      #local_no_record=[]
      # @user=user
      # @repo=repo
      builds=[]
      Thread.abort_on_exception = true       
      threads = init_find_vcommit 
      Repo_data_travi.where("repo_name=?","#{user}@#{repo}").find_each  do |info|
        build= info.attributes.deep_symbolize_keys
        @queue.enq build
        #@queue.enq build
        
      end
      puts $builds.size
      builds=$builds.select {|x| !x.nil?}
     
      builds = builds.group_by { |x| x[:build_id] }.map { |k, v| v[0] }
    # write_file(lost_commit,@parent_dir,"lost_commit.json")
      #write_file(no_record_commit,@parent_dir,"no_record_commit.json")
      puts "initial builds size #{builds.size}"
      write_file(builds,@parent_dir,"all_repo-data-virtual-builds.json")
      ActiveRecord::Base.clear_active_connections!
      begin
        All_repo_data_virtual.import builds
      rescue => exception
        
        
      ensure
        FixSql.process_dup(user,repo)
        ActiveRecord::Base.clear_active_connections!
      #FixSql.process_dup2(user,repo)
        puts "dup1 clear"
        build_state_threads(user,repo)
      end
    end
      
    
    
      #puts build
      # threads=[] 
      # threads = thread_init
     
        
      #builds = load_all_builds(@parent_dir, "all_repo-data-virtual-builds.json")
      
      #puts builds.class
      #build_state(user,repo1)
  end






def self.init_build_state
  @queue=SizedQueue.new(@thread_num)
  threads=[]
  @thread_num.times do 
    thread = Thread.new do
      loop do
        arry = @queue.deq
        break if arry == :END_OF_WORK
        # if arry[0][:commit]=='df778b7b80d290802ec8268d40ca70f7182cd118'
        #   next
        # end
        #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
        pre_commit=[]
        $id=arry[0][:id]
        next if $id==283526
        puts "begin id #{$id}"  
        #puts "id : #{arry[0][:id]}"
        build_stat={
          arry[0][:commit].to_sym =>  find_commits_to_prior(arry[1],arry[0],arry[0][:commit],pre_commit,0,0)
        }
        puts "write file"
        write_file_add(build_stat,@parent_dir,"test_build_state.json")
        $build_stats << build_stat
        #write_file_add(build_stat,@parent_dir,"build_state_temp.json")
        
        
      end
      end
      threads << thread
    end

  threads
end

  
def self.build_state_threads(user,repo)
  
  
  
  Thread.abort_on_exception = true 
  threads = init_build_state
  $build_stats=[]
  $global_arry=[]
  $author_arry=[]
  builds=[]
   
    #这里需要对数据库all_repo_data_virtual去重生成no_dupall_repo_data_virtual2.json
    
    FixSql.process_dup(user,repo)
    FixSql.process_dup2(user,repo)
    commit_json = File.join(@parent_dir, "no_dupall_repo_data_virtual2.json")
   

    
    
      All_repo_data_virtual.where("repo_name=? ","#{user}@#{repo}").find_each  do |info|
       
        builds << info.attributes.deep_symbolize_keys
        
      end
      write_file(builds,@parent_dir,"no_dupall_repo_data_virtual2.json")
    

      #fdir = File.join("build_logs", "#{user}@#{@repo}", "all_repo_virtual_prior_mergeinfo_father_id.json")
     
      fdir_content = load_all_builds(@parent_dir, "all_repo_virtual_prior_mergeinfo_father_id.json")
      if fdir_content.size>10 
        DiffTest.test_diff(user,repo) 
      else
        path=File.join(@parent_dir, "test_build_state.json")
        puts path
        if File.exists?(path)#如果前一次运行失败了，这一次就直接
          FixSql.fix_virtual_file(@parent_dir)
          $build_stats=load_all_builds(@parent_dir,"build_stats.json")
        else
          builds.each do |build|
            #All_repo_data_virtual.where("commit=?","4a4e072446377cee77d06220af0b716c22b27dbb").find_each do |build|
              #  puts build[:id]
              # puts "build的class#{build.class}"
              @queue.enq [build,builds]
                
                #build_stats << build_stat
                
              
          end
            @thread_num.times do   
            @queue.enq :END_OF_WORK
            end
            threads.each {|t| t.join}
            puts "BUildStateUpdate Over"
        end
          
          #write_file($build_stats,@parent_dir,"build_stats.json")  不写build_stats
          #FixSql.fix_virtual_file(user,repo)#将build_tmp_stats写为build_stats
          #build_stats=load_all_builds(@parent_dir, "build_stats.json")
          puts "$build_stats :#{$build_stats.size}"
          $build_stats.each do |build_info|
            
            iterate(build_info,[],0,[])
          end
         
          #write_file(build_stats,@parent_dir,"build_stats.json")
          #write_file(@local_miss_commit,@parent_dir,"local_miss_commit.json")
          
          puts "global_arry"
          #puts $global_arry
          #puts $author_arry
          #write_file($global_arry,@parent_dir,"global_arry.json")
          write_file($author_arry,@parent_dir,"author_arry.json")
      
          for i in (0..$global_arry.size-1)
            $global_arry[i]=$global_arry[i].merge($author_arry[i])
          end
          #write_file($global_arry,@parent_dir,"complete_global.json")
          
           $global_arry.reject{|arry| arry.nil?}
           write_file($global_arry,@parent_dir,"global_arry.json")
          #f = File.join("git_travis_torrent/build_logs", "#{user}@#{repos}")
           filename="all_repo_virtual_prior_mergeinfo.json"
           global_arry_copy=$global_arry.dup
           no_parent_build=[]
           global_arry_copy=global_arry_copy.map do |b|
           if not ((builds.find { |bs| bs[:commit] == b[:last_build_commit]  }.nil?) and (builds.find { |bs| bs[:merge_commit] == b[:last_build_commit]  }.nil? ))
            !builds.find { |bs| bs[:commit] == b[:last_build_commit]  }.nil? ? b=b.merge(builds.find { |bs| bs[:commit] == b[:last_build_commit]}): b=b.merge(builds.find { |bs| bs[:merge_commit] == b[:last_build_commit]})
           else
              no_parent_build << b[:now_build_commit]
              $global_arry.delete(b)
           end
           b
           end
           global_arry_copy.select!{|m| !no_parent_build.include? m[:now_build_commit]}
           global_arry_copy.uniq!
           write_file(global_arry_copy,@parent_dir,filename)
           write_file(no_parent_build,@parent_dir,"no_parent_build.json")
           
           FixSql.insert_into_temp_prior(@parent_dir)#增加father_id
           puts "father id added "
           
           DiffTest.test_diff(user,repo) 
      end
      
      
   
    #All_repo_data_virtual.where("repo_name=? and id>0","#{user}@#{repo}").find_each do |build|
     
  
  end

 
  def iterate(h,key_val,flag,z)
    if h.is_a?(Hash)
      h.each do |k,v|
        key=k
        value = v 
    
    
        if value.is_a?(Hash) || value.is_a?(Array)||key.is_a?(Hash)||key.is_a?(Array)
          if !key.empty?&&flag==0
            key_val<<key
            
            if value.empty?
              
             z << iterate(key,key_val,1,z)
             
            else
             z << iterate(value,key_val,1,z)
              
            end
    
          elsif value.is_a?(Array)
            key_val<<key 
           z<< iterate(value,key_val,1,z)
          
          else 
           z<< iterate(value,key_val,1,z)
           
          end
    
        
        end
      end
    elsif h.is_a?(Array)
      if h[0].is_a?(String)|| h[0].is_a?(Numeric) 
        temp=key_val.pop
        # puts "ary_key: #{temp} arry_value:#{h}"
        # puts temp.class
        if temp==:commits
          
          #puts "key_val.class:#{key_val.class}"
          #puts "key_val.class:#{key_val[0].class}"
          commit_list={
            :now_build_commit=>key_val[0].to_s,
            :commit_list=> h,
            :last_build_commit=>h.last
          }
          $global_arry<<commit_list
          end
          if temp == :authors
            author_list={
              :authors=>h,
              :num_author=>h.size
            }
          $author_arry << author_list
          end
        #puts commit_list
        
        
        
        
        return $global_arry
      else
        h.each do |a|
         
          z<<iterate(a,key_val,1,z)
         
         
    
    
        
      end
      end
    
    
    
    end
    end 
 #get prior commits to last build
 '''
 只找到本地的数据，会有本地找不到的commit情况，暂时没有考虑
 '''

# def find_commits_to_prior(builds,build,sha,prev_commits,flag)

       
#        puts"==================================="
#        begin
#         repo = Rugged::Repository.new("repos/#{@user}/#{@repo}")
        
#         build_commit = repo.lookup(sha)
#         #puts "build_commit#{build_commit}  #{build_commit.oid} "
#        rescue
#         puts "cannot find locally!"
#         @local_miss_commit<<sha
#         return
#         #c=github_commit(@user,@repo,sha,rand(0..6)) 
#        end
#        if build_commit.nil? 
#           return
       
#        end
#       #unless build_commit.nil?
#       walker = Rugged::Walker.new(repo)
#       walker.sorting(Rugged::SORT_TOPO)
#       walker.push(build_commit)
     
#       #else prev_commits << 
#       commit_resolution_status = :no_previous_build
#       last_commit = nil
#       i=0
#       walker.each do |commit|
#         i=i+1
#         last_commit = commit
#         if i==1
#             prev_commits << commit
            
#         end
        
#         #puts "last_commt#{i}#{[last_commit]}"
#         puts "last_commit.oid:#{last_commit.oid}"
#         puts "commit_oid#{commit.oid}"
        
#         if commit.oid == build_commit.oid#build_commit本身是一个merge
#           if commit.parents.size > 1
#             commit_resolution_status = :merge_found
#             puts "build_commit本身是一个merge"
#             if flag==0#如果是第一层build，就要继续找下去
#               acc=[]
#               j=0
#               commit.parent_ids.each do |shas|
               
                
#                 while prev_commits.last.oid!=build_commit.oid
#                 prev_commits.pop
#                 end
#                 acc << find_commits_to_prior(builds,build,shas,prev_commits,1)
#               end
#               return acc
            
#             elsif flag==1#如果是已经找到父commit了，父亲是一个build_commit且有两个parents  flag=1
#               if not builds.select { |b| b[:commit] == commit.oid }.empty?#不为空
#                 commit_resolution_status = :build_found#找到上一次的build_commit
            
            
#                 puts"在第二层找到上一次build_commit"
                
#                 prev_commits.uniq
#                 #puts "prev_commits1 #{prev_commits}"
#                 break
              
#               else#这个merge不是build
#                acc=[]
#                j=0
#                 commit.parent_ids.each do |shas|
                 
#                   prev_copy_commit=[build_commit]
#                   while prev_commits.last.oid!=build_commit.oid
#                     prev_commits.pop
#                   end
#                   #puts "22这里的 pre_commits #{prev_commits}"
#                   acc << find_commits_to_prior(builds,build,shas,prev_commits,1)
#                 end
#                 return acc
#               end

#             end
          



#           else
#             puts "当前commit 只有一个parent"
#             if flag==1 
#               if not builds.select { |b| b[:commit] == commit.oid }.empty?
#                 #if not builds.select { |b| b[:commit] == commit.oid }.empty?#不为空
#                     commit_resolution_status = :build_found#找到上一次的build_commit
                
                
#                     puts"在第二层找到上一次build_commit"
                    
#                     prev_commits.uniq
#                     #puts "prev_commits1 #{prev_commits}"
#                     break
                
#                 else
#                 next
#                 end 
#             else
#                 next
#             end
#           end
          
#         end

#         if not builds.select { |b| b[:commit] == commit.oid }.empty?#不为空
#           commit_resolution_status = :build_found#找到上一次的build_commit
          
          
#           puts"找到上一次build_commit"
#           prev_commits << commit
#           prev_commits.uniq
#          # puts "prev_commits2 #{prev_commits}"
#           break
       
#         end

#         prev_commits << commit

#         if commit.parents.size > 1#这个commit不是built_commit，但是有两个parents
#           commit_resolution_status = :merge_found
#           puts "这个commit不是built_commit，但是有两个parents"
#           acc=[]
          
#           commit.parent_ids.each do |shas|
#               prev_copy_commit=[build_commit]
#                   while prev_commits.last.oid!=build_commit.oid
#                     prev_commits.pop
#                   end
            
#               acc << find_commits_to_prior(builds,build,shas,prev_commits,1) 
#           end
#           return acc    
          
#         end

#       end

#       puts "#{prev_commits.size} built commits (#{commit_resolution_status}) for build #{sha}"
    
#     build_stats=
#       {
#           :build_id => build[:build_id].to_i,
#           #:commit_sha => build[:commit],
#           :prev_build => if not commit_resolution_status == :merge_found
#                            builds.find { |b| b[:build_id] < build[:build_id].to_i and last_commit.oid.start_with? b[:commit] }
#                           else
#                            nil
#                          end,
#           :commits => prev_commits.map { |c| c.oid },#从当前buildcommit到上一次build_commit之前，包括上一次build_commit
#           :authors => prev_commits.map { |c| c.author[:email] }.uniq,
#           :prev_built_commit => commit_resolution_status == :merge_found ? nil : (last_commit.nil? ? nil : last_commit.oid),
#           :prev_commit_resolution_status => commit_resolution_status
#       }
      
#     return build_stats
# end 
def find_commits_to_prior(builds,build,sha,prev_commits,flag,count)
  
  no_record_commit=[]
  File.open(File.join(@parent_dir,"no_record_commit.json"), "r") do |file|
  file.each_line do |line|
      #puts line()
      #ch=line
      no_record_commit << JSON.parse(line)
      #puts ch
      #break
  end
  end
  puts"==================================="
  begin
   #puts @user
   #如果往前找的次数太多,就放弃
   
   puts "id:#{$id}"
   if count>13
    puts "往前找的次数太多,放弃1"
    return nil
   end
   count+=1
   checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository', @user+'@'+ @repo),File.dirname(__FILE__)) 
   repo = Rugged::Repository.new(checkout_dir)
   
   build_commit = repo.lookup(sha)
   #puts "build_commit#{build_commit}  #{build_commit.oid} "
   c={}
  rescue
    puts "cannot find local!"
    puts "sha: #{sha}"
   
    if no_record_commit.include? sha
      puts "no record include sha"
      return nil
    else
      c=ParseHtml.github_commit(@user,@repo,sha,rand(0..3))
    end
   
  end
  if build_commit.nil? && (c.empty?)
      puts "本地和远程都找不到"
      return nil
  end
           
  if !build_commit.nil?
 
      walker = Rugged::Walker.new(repo)
      walker.sorting(Rugged::SORT_TOPO)
      walker.push(build_commit)


      commit_resolution_status = :no_previous_build
      last_commit = nil
      i=0
      walker_new=Array.new
      walker.each do |commit|
        walker_new << commit
        
      end
      #puts walker_new.count
      walker_new.each  do|commit|

        #puts walker_new.count
        i=i+1
        
        last_commit = commit.oid
        if i==1
            prev_commits << {:oid=>commit.oid,:committer=>commit.committer[:email]}
            
        end
        
        #puts "last_commt:#{i}#{[last_commit]}"
        #puts "外层last_commit.oid:#{last_commit.oid}"
        #puts "外层commit_oid:#{commit.oid}"
        #puts "build_commit.oid:#{build_commit.oid}"
        if commit.oid == build_commit.oid#build_commit本身是一个merge
          if commit.parents.size > 1
            commit_resolution_status = :merge_found
            #puts "build_commit本身是一个merge,两个parents"
            if flag==0#如果是第一层build，就要继续找下去
              acc=[]
              j=0
              commit.parent_ids.each do |shas|
                
                
                
                while prev_commits.last[:oid]!=build_commit.oid
                prev_commits.pop
                end
                #puts "build_commit本身是一个merge,两个parents"
                acc << find_commits_to_prior(builds,build,shas,prev_commits,1,count)
                
              end
              return acc
            
            elsif flag==1#如果是已经找到父commit了，父亲是一个build_commit且有两个parents  flag=1
              if not (builds.select { |b| b[:commit] == commit.oid }.empty? &&  builds.select { |b| b[:merge_commit] == commit.oid }.empty?)  #不为空
                commit_resolution_status = :build_found#找到上一次的build_commit
                
                
            #puts commit.message
           # puts "last_commit.oid #{last_commit.oid}"
            
               #puts"在第二层找到上一次build_commit"
                
                prev_commits.uniq!
                #puts "prev_commits1 #{prev_commits}"
                break
              #elsif builds.select { |b| b[:commit] == commit.oid }.empty?==False &&  builds.select { |b| b[:merge_commit] == commit.oid }.empty?==False
              else#这个merge不是build
                acc=[]
                j=0
                commit.parent_ids.each do |shas|
                  
                  prev_copy_commit=[build_commit]
                  while prev_commits.last[:oid]!=build_commit.oid
                    prev_commits.pop
                  end
                  #puts "这个merge不是build"
                  #puts "22这里的 pre_commits #{prev_commits}"
                  #puts "这个merge不是build"
                  acc << find_commits_to_prior(builds,build,shas,prev_commits,1,count)
                end
                return acc
              end

            end
          



          else
            #puts "当前commit 只有一个parent"
            #puts "commit.parent_ids: #{commit.parent_ids}"
            if flag==1 
                #puts "flag=1"
                if not (builds.select { |b| b[:commit] == commit.oid }.empty? &&  builds.select { |b| b[:merge_commit] == commit.oid }.empty?)#不为空
                    commit_resolution_status = :build_found#找到上一次的build_commit
                   
                    #puts "commit.oid -> #{commit.oid}"
                    
                    #puts "last_commit.oid #{last_commit.oid}"
                    
                        #puts"只有一个parent.在第二层找到上一次build_commit"
                        
                        prev_commits.uniq!
                        #puts "prev_commits1 #{prev_commits}"
                    break
                
                else
                  
                  #puts"只有一个parent.在第二层没有找到build_commit"
                  next
                end
                 
            else
              #puts "flag==0"
              next
            end
          end
          
        end

        if not (builds.select { |b| b[:commit] == commit.oid }.empty? &&  builds.select { |b| b[:merge_commit] == commit.oid }.empty?)#不为空
          commit_resolution_status = :build_found#找到上一次的build_commit
          #puts commit.class
          #puts "commit.oid#{commit.oid}"
          
          #puts "last_commit.oid #{last_commit.oid}"
          
          #puts"if not 找到上一次build_commit"
          prev_commits << {:oid=>commit.oid,:committer=>commit.committer[:email]}
          prev_commits.uniq!
          #puts "prev_commits2 #{prev_commits}"
          break
        end
        if  i==walker.count or i>13
          puts "往前找的次数太多,放弃2"
          #puts"已经找到第一次commit,无法继续"
          return nil
        end
        
        prev_commits << {:oid=>commit.oid,:committer=>commit.committer[:email]}

        #puts "非build的parents_ids-> #{commit.parent_ids}"
        if commit.parents.size > 1#这个commit不是built_commit，但是有两个parents
          commit_resolution_status = :merge_found
          #puts "这个commit不是built_commit，但是有两个parents"
          acc=[]
          
          commit.parent_ids.each do |shas|
                prev_copy_commit=[build_commit]
                  while prev_commits.last[:oid]!=commit.oid
                    prev_commits.pop
                  end
            #puts "这个commit不是built_commit，但是有两个parents,prev_commits "
            acc << find_commits_to_prior(builds,build,shas,prev_commits,1,count) 
          end
          return acc 
        else
          # acc=[]
          # #puts "commit.parent_ids[0]: #{commit.parent_ids[0]}"
          # # while prev_commits.last.oid!=build_commit.oid
          # #   prev_commits.pop
          # # end 
          # acc << find_commits_to_prior(builds,build,commit.parent_ids[0],prev_commits,1) 
          # return acc
          #if commit.parents.size == 1
          
          #puts "这个commit不是built_commit，1个parents"
          next
        end  
          
        

      end
    
  elsif !c.empty?# 用api获取的信息c
    count+=1
    commit_resolution_status = :no_previous_build
     last_commit =  sha
    
      prev_commits << {:oid=>sha,:committer=>  c['commit']['committer']['email']}
    
    
      if flag==0
        acc=[]
        for info in c['parents'] do
          while prev_commits.last[:oid]!=sha
            prev_commits.pop
          end
          #puts "api many_parent"
          acc << find_commits_to_prior(builds,build,info["sha"],prev_commits,1,count)
        end
        return acc
      else
        if not (builds.select { |b| b[:commit] == sha }.empty? && builds.select { |b| b[:merge_commit] == sha }.empty?) #不为空
           commit_resolution_status = :build_found#找到上一次的build_commit
            
           
            #puts commit.message
            
          
           #puts" parsehtml 在第二层找到上一次build_commit"
           
           prev_commits.uniq!
          
           #puts "prev_commits1 #{prev_commits}"
           
         
        else#这个merge不是build
          acc=[]
          #puts "parsehtml 这个merge不是build"
          for info in c['parents'] do
            while prev_commits.last[:oid]!=sha
              prev_commits.pop
            end
            #puts "parsehtml 这个merge不是build"
            acc << find_commits_to_prior(builds,build,info["sha"],prev_commits,1,count)
          end
          return acc
          
          
        end
      end
             
     
  else
       
  end


puts "#{prev_commits.size} built commits (#{commit_resolution_status}) for build #{prev_commits.first[:oid]}"
if commit_resolution_status != :build_found
  return nil
else
small_build_stats=
  {

     :build_id => build[:build_id],
     #:commit_sha => build[:commit],
     :prev_build => if not (commit_resolution_status == :merge_found or commit_resolution_status ==:no_previous_build)
                      builds.find { |b| b[:build_id] < build[:build_id] and  (last_commit.start_with? b[:commit] or b[:merge_commit] unless b[:merge_commit].nil? ) }
                    else
                      nil
                    end,
     #:commits =>prev_commits,
     :commits => prev_commits.map { |c| c[:oid] },#从当前buildcommit到上一次build_commit之前，不包括上一次build_commit
     :authors => prev_commits.map { |c| c[:committer] }.uniq,
     :prev_built_commit => commit_resolution_status == :merge_found ? nil : (last_commit.nil? ? nil : last_commit),
     :prev_commit_resolution_status => commit_resolution_status
 }
   #puts  small_build_stats
   return small_build_stats
end
end

#抽commit详细信息，包括travis上的虚拟commit sha 
# def github_commit (owner, repo, sha,k)
#     parent_dir = File.join('commits', "#{owner}@#{repo}")
#     commit_json = File.join(parent_dir, "#{sha}.json")
#     FileUtils::mkdir_p(parent_dir)

#     r = nil
#     i=1
#   if File.exists? commit_json  
#       r= begin
#         JSON.parse File.open(commit_json).read
#     rescue
#        {}
      
#     end
#     return r if !r.empty?
#   end
#   if i==1
#     unless r.nil? || r.empty?
#         return r
      
#     else
     

#     url = "https://api.github.com/repos/#{owner}/#{repo}/commits/#{sha}"
#     puts "Requesting #{url} (#{@remaining} remaining)"

#     contents = nil
#     begin
#       puts "begin"
#       puts @token[k]
#       r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{@token[k]}")
      
#       @remaining = r.meta['x-ratelimit-remaining'].to_i
#       puts "@remaining"
#       puts @remaining
#       @reset = r.meta['x-ratelimit-reset'].to_i
#       contents = r.read
#       JSON.parse contents
#     rescue OpenURI::HTTPError => e
#       @remaining = e.io.meta['x-ratelimit-remaining'].to_i
#       @reset = e.io.meta['x-ratelimit-reset'].to_i
#       puts  "Cannot get #{url}. Error #{e.io.status[0].to_i}"
#       {}
#     rescue StandardError => e
#       puts "Cannot get #{url}. General error: #{e.message}"
#       {}
#     ensure
#       File.open(commit_json, 'w') do |f|
#         f.write contents unless r.nil?
#         if r.nil? and 5000 - @remaining >= 6
#           github_commit(owner, repo, sha,rand(0..4))
#         end
        
      
#       end

#       if 5000 - @remaining >= $REQ_LIMIT
#         to_sleep = @reset - Time.now.to_i + 2
#         puts "Request limit reached, sleeping for #{to_sleep} secs"
#         sleep(to_sleep)
#       end
#     end
#   end
#   end
# end


    




    
 


def test_prior(user,repo)
  builds = load_all_builds(@parent_dir, "all_repo_data_virtual2.json")
  
  build={"id":2217,"repo_name":"google@guava","build_id":"88225502","commit":"5ba29c73b229f2387c1fb49f97848833e172c5ce","pull_req":2112,"branch":"master","status":"errored","message":"add gwt-emulation for ThreadLocalBuffers.getByteArray() to fix tests","duration":662,"started_at":"2015-10-29T23:24:36Z","jobs":[88225503,88225504,88225505],"event_type":"pull_request","author_email":"berndjhopp@gmail.com","committer_email":"berndjhopp@gmail.com","tr_virtual_merged_into":"d00572edf1c42f9fc9d2419a615588404efd656a","merge_commit":"3a441a1bdc5c9ad709bed7ca0301906fe8d1844f"}
  pre_commit=[]
  build_stats=[]
        build_stat={
          build[:commit].to_sym =>  find_commits_to_prior(builds,build,build[:commit],pre_commit,0)
        }
         
        #write_file_add(build_stat,@parent_dir,"test_build_state.json")
       # write_file_add(build_stat,@parent_dir,"build_state_temp.json")
        build_stats << build_stat
        puts build_stats

end

def method_name
  repo_name=IO.readlines('new_reponame.txt')
  i=0
  # repo_name.each do |line|
  #   line = JSON.parse(line)
    
  #   @user = line.split('/').first
  #   @repo = line.split('/').last
  #   @parent_dir = File.join('build_logs/',  "#{@user}@#{@repo}")
  #   if i>=10
  #     clone(line.split('/').first,line.split('/').last)
  #     i+=1
  #   else
  #     i+=1
  #   end
  # end
  i=0
  repo_name.each do |line|
    line = JSON.parse(line)
    
    @user = line.split('/').first
    @repo = line.split('/').last
    
    @parent_dir = File.join('build_logs/',  "#{@user}@#{@repo}")
    
    if i>=6
      ActiveRecord::Base.clear_active_connections!
      process(@user,@repo)
      #commitinfo(@user,@repo)
      #found_vcommit(@user,@repo)
      #build_state_threads(line.split('/').first,line.split('/').last)
      i+=1
      #break
    else
     i+=1
    end
  
    # #build_state_threads('HubSpot','Singularity')
    # build_state(@user,@repo)
    
    # break
    
   
  #   #build_state_threads(line.split('/').first,line.split('/').last)
    
  end
end
# owner = ARGV[0]


# repo = ARGV[1]
method_name
# arry=["eb37fce20c89a3bd14be623ef03bb242118159b0",
# "b8e9edd09d9008e6f65f5751dd7ad6ecc0004eb4",
# "46d759b3836e2e78bae251e6ff7d727d88d53554",
# "cb65d46a8e2618a086020db188b6f1eb60f355ad",
# ca0cefbf423573c78395ea9bc8914a13dad2bf47
# 2155f74c5b2a9f877fe84d2a7716282569bb8487
# 9efb11d7bf6952a00473d16ab63fe18c10d0e57a
# 8444c6312eea167bf2ec642db1f2cb6dc8cc73b2
# 8eee968957079d707214beb460b77e67ce9ac53c
# 61b01c1de2c32db125907a72d79a68ce7e88abea
# 2038d32ea0e4dc819f7b085535facfc9e2160bca
# dd2670e66be0e164ccf4521a501c113981c1e201
# 4cfa50c6b30a6aec49ad1c3d824c5e9576a54303
# b19a5db803f737eeb3a174e77e82ed76d9f6e056
# 58abe578f5c25f158e4f5ad2612db15daf7e84dc
# c8263b4d9491ca52b12934f4503dae68d756ed0d
# 1ccad68897a760d735285530c988e7e37414b41c"]


#github_commit("#{owner}","#{repo}","f91ef6ca6dd95bd3806c8b573f54cd429abc5857")
#test("#{owner}","#{repo}")
#all_repo_data("#{owner}","#{repo}")
#build_state("#{owner}","#{repo}")

#build_state_threads("#{owner}","#{repo}")

#found_vcommit("#{owner}","#{repo}")
#test_github_commit("#{owner}","#{repo}")
#lost_commit("#{owner}","#{repo}")
#test_prior("#{owner}","#{repo}")


# repo = Rugged::Repository.new("repos/#{owner}/#{@repo}")
   
# build_commit = repo.lookup("7ce15b725d84f335b56a93332cad1a0af9b48cf7")
# puts build_commit
# walker = Rugged::Walker.new(repo)
# walker.sorting(Rugged::SORT_TOPO)
# walker.push(build_commit)
# walker.each do |commit|
#   puts commit.parent_ids
#   break

# end

