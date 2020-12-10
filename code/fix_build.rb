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
require File.expand_path('../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
  

  
  
  
class  FixBuild
#查看数据库发现有一些build没有追溯前一次build的记录，即all-repo_merge表缺少数据    
  $global_arry=[]
  $author_arry=[]
  $build_stats=[]
  
  def initialize(user,repo)
      @user=user
      @repo=repo
      @thread_num=60
  end
  def load_all_builds(rootdir,filename)
    f = File.join(rootdir, filename)
    unless File.exists? f
      puts "不能找到"
      return {}
    end

    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
  end

  def load_builds()
    f = File.join("build_logs", "#{@user}@#{@repo}", "repo-data-travis.json")
    unless File.exists? f
      puts "不能找到"
    end

    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
  end


  def load_commit()
    f = File.join("build_logs", "#{@user}@#{@repo}", "commits_info.json")
    unless File.exists? f
      puts "不能找到"
    end

    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
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
    if !File.directory?(parent_dir)
      FileUtils::mkdir_p(parent_dir)
    end
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

  def init_build_state
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
            next if ($id==283526 or $id == 41868)
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
    
      
    def build_state_threads()
      
      @original_parent_dir=File.join('build_logs/',  "#{@user}@#{@repo}")
      @parent_dir = File.join('fix_build_logs/',  "#{@user}@#{@repo}")
    
      Thread.abort_on_exception = true 
      threads = init_build_state
      
      $global_arry=[]
      $author_arry=[]
      builds=[]
      all_repo_id=[]
      all_merge_id=[]
      left_id=[]
      
        #这里需要对数据库all_repo_data_virtual去重生成no_dupall_repo_data_virtual2.json
        
        
        
          All_repo_data_virtual.where("repo_name=? and status != 'canceled'","#{@user}@#{@repo}").find_each  do |info|
            
            all_repo_id << info.build_id
            
          end
          All_repo_data_virtual_prior_merge.where("repo_name=? ","#{@user}@#{@repo}").find_each  do |info|

            all_merge_id<< info.now_build_id
          end
          puts(all_merge_id.uniq!)
          puts all_merge_id.size
          puts all_repo_id.size
          puts "差集 #{(all_repo_id-all_merge_id).size}"
          
          all_merge_id.uniq!
          left_id=all_repo_id-all_merge_id
         
        
          All_repo_data_virtual.where("repo_name=? ","#{@user}@#{@repo}").find_each  do |info|
          
            builds << info.attributes.deep_symbolize_keys
            
          end
          
        
    
          #fdir = File.join("build_logs", "#{user}@#{@repo}", "all_repo_virtual_prior_mergeinfo_father_id.json")
        
        
            path=File.join(@parent_dir, "test_build_state.json")
            
            puts left_id
            if File.exists?(path)#如果前一次运行失败了，这一次就直接
              FixSql.fix_virtual_file(@parent_dir)#重写为build_stats.json文件
              $build_stats=load_all_builds(@parent_dir,"build_stats.json")
            else
              # builds.each do |build|
              for item in left_id
                All_repo_data_virtual.where("build_id=?",item).find_each do |build|
                  #  puts build[:id]
                  # puts "build的class#{build.class}"
                  @queue.enq [build,builds]
                    
                    #build_stats << build_stat
                    
                  
                end
              end
                @thread_num.times do   
                @queue.enq :END_OF_WORK
                end
                threads.each {|t| t.join}
                puts "BUildStateUpdate Over"
            end
              
            
              puts "$build_stats :#{$build_stats.size}"
              $build_stats.each do |build_info|
                
                iterate(build_info,[],0,[])
              end
            
              #write_file(build_stats,@parent_dir,"build_stats.json")
              #write_file(@local_miss_commit,@parent_dir,"local_miss_commit.json")
              
              puts "global_arry"
             
              #write_file($global_arry,@parent_dir,"global_arry.json")
              write_file($author_arry,@parent_dir,"author_arry.json")
          
              for i in (0..$global_arry.size-1)
                $global_arry[i]=$global_arry[i].merge($author_arry[i])
              end
              #write_file($global_arry,@parent_dir,"complete_global.json")
              
              $global_arry.reject{|arry| arry.nil?}
              
              #f = File.join("git_travis_torrent/build_logs", "#{user}@#{repos}")
              filename="all_repo_virtual_prior_mergeinfo.json"
              global_arry_copy=$global_arry.dup
              no_parent_build=[]
              no_parent_lsit=[]
              global_arry_copy=global_arry_copy.map do |b|
              if not ((builds.find { |bs| bs[:commit] == b[:last_build_commit]  }.nil?) and (builds.find { |bs| bs[:merge_commit] == b[:last_build_commit]  }.nil? ))
                !builds.find { |bs| bs[:commit] == b[:last_build_commit]  }.nil? ? b=b.merge(builds.find { |bs| bs[:commit] == b[:last_build_commit]}): b=b.merge(builds.find { |bs| bs[:merge_commit] == b[:last_build_commit]})
              else
                  no_parent_build << b[:now_build_commit]
                  no_parent_lsit << b
                  $global_arry.delete(b)
              end
              b
              end
              
              global_arry_copy.select!{|m| !no_parent_build.include? m[:now_build_commit]}
              global_arry_copy.uniq!
              puts "after seelct!: \n #{global_arry_copy}"
              write_file(global_arry_copy,@parent_dir,filename)
              write_file(no_parent_build,@parent_dir,"no_parent_build.json")
              write_file(no_parent_list,@parent_dir,"no_parent_list.json")
              
              FixSql.insert_into_temp_prior(@parent_dir)#增加father_id
              puts "father id added "
              
              DiffTest.test_diff(@user,@repo,0,0,1) 
          
          
          
      
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

        def find_commits_to_prior(builds,build,sha,prev_commits,flag,count)
    
          no_record_commit=[]
          File.open(File.join(@original_parent_dir,"no_record_commit.json"), "r") do |file|
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
          if count>10
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
                if  i==walker.count or i>10
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
  end
  repo_name=IO.readlines('repo_name.txt')
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
  
  repo_name.each do |line|
    line = JSON.parse(line)
    
    user = line.split('/').first
    repo = line.split('/').last
    
    # @parent_dir = File.join('build_logs/',  "#{@user}@#{@repo}")
    
    if i>=0
      ActiveRecord::Base.clear_active_connections!
      fixbuild=FixBuild.new(user,repo)
     fixbuild.build_state_threads()
      #commitinfo(@user,@repo)
      #found_vcommit(@user,@repo)
      #build_state_threads(line.split('/').first,line.split('/').last)
      i+=1
      
    else
     i+=1
    end
  
    # #build_state_threads('HubSpot','Singularity')
    # build_state(@user,@repo)
    
    # break
    
   
  #   #build_state_threads(line.split('/').first,line.split('/').last)
    
end

  
  
  # FixBuild.build_state_threads('apache','flink')