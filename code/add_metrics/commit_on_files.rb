require 'active_record'
require 'activerecord-import'
class CommitInfo < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.141.221.85",
      username: "xx",
      password: "xx",
      database: "xx",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin",
      pool: 300
  )
  has_many :commit_files
end

class CommitFile < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.141.221.85",
      username: "xx",
      password: "xx",
      database: "xx",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin",
      pool: 300
  )
end

class AllRepoDataVirtualPriorMerge < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
      host:     "10.141.221.85",
      username: "xx",
      password: "xx",
      database: "xx",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin",
      pool: 300
  )
  serialize :commit_list, Array
end
class AllRepoDataVirtual < ActiveRecord::Base
  establish_connection(
      adapter:  "mysql",
       host:     "10.141.221.85",
      username: "xx",
      password: "xx",
      database: "xx",
      encoding: "utf8mb4",
      collation: "utf8mb4_bin",
      pool: 300
  )
  serialize :commit_list, Array
end

def self.run(user,repo)
  AllRepoDataVirtualPriorMerge.where("commit_on_files=0 or commit_on_files is null and repo_name=?","#{user}@#{repo}" ).find_each do |build|
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
    build.commit_on_files = count
    build.save
  end
end

def start(user,repo)
  Thread.abort_on_exception = true
        threads = init_commit
        info=AllRepoDataVirtualPriorMerge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=AllRepoDataVirtualPriorMerge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        AllRepoDataVirtualPriorMerge.where("repo_name=?  and now_build_id<=? and now_build_id>=? and (commits_on_files=0 or commits_on_files is null)","#{user}@#{repo}",last_id,first_id).find_each do |info|
            
            @inqueue.enq info
        end
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "pr_src_files Update Over=========="
        return 
  
end
def init_commit
  @inqueue = SizedQueue.new(@thread_num)
  threads=[]
  @thread_num.times do 
          thread = Thread.new do
              loop do
              build = @inqueue.deq
              break if build == :END_OF_WORK
              
              count = 0 
              repo_name = build.repo_name
              
              current_files = []
              dt = nil 
              build.commit_list.each do |sha|
                ci = CommitInfo.find_by(commit: sha)
                next if ci.nil?
                dt = ci.commit_date if dt.nil? || dt > ci.commit_date
                
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
              build.commits_on_files = count
              build.save
              
              
              end
          end
              threads << thread
          end
          threads
end

def is_master(user,repo)
  Thread.abort_on_exception = true
        threads = init_master
        info=AllRepoDataVirtualPriorMerge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=AllRepoDataVirtualPriorMerge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        AllRepoDataVirtualPriorMerge.where("repo_name=?  and now_build_id<=? and now_build_id>=? ","#{user}@#{repo}",last_id,first_id).find_each do |info|
            
            @inqueue.enq info
        end
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "master Over=========="
        return 
  
end

def init_master
  @inqueue = SizedQueue.new(@thread_num)
  threads=[]
  @thread_num.times do 
          thread = Thread.new do
              loop do
              build = @inqueue.deq
              break if build == :END_OF_WORK
              
              allrepo=AllRepoDataVirtual.find_by(build_id: build.now_build_id)
              next if allrepo.nil?
              if allrepo.branch=='master'
                build.now_is_master = 1
                build.save
              end
              
              
              end
          end
              threads << thread
          end
          threads
end
def count_num(user,repo)
  # Thread.abort_on_exception = true
  #       threads = init_master
        info=AllRepoDataVirtualPriorMerge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        # p first_id
        last_info=AllRepoDataVirtualPriorMerge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        # p last_id
        p AllRepoDataVirtualPriorMerge.where("repo_name=?  and now_build_id<=? and now_build_id>=? and last_label=1 and last_fail_gap_sum is null","#{user}@#{repo}",last_id,first_id).count
            
          
        # @thread_num.times do   
        # @inqueue.enq :END_OF_WORK
        # end
        # threads.each {|t| t.join}
        # puts "master Over=========="
        return 
  
end

def self.method_name
  # parent_dir = File.expand_path('../../new_reponame.txt',__FILE__)
  parent_dir = File.expand_path('../../repo_name.txt',__FILE__)
    repo_name=IO.readlines(parent_dir)
    i=0
    @thread_num=10
    repo_name.each do |line|
        # line = JSON.parse(line)
        
        # line=line.reject{|x| x=='"'}
        puts line
        a=line.split('"')[1]
       
        
        user=a.split('/').first
        repo=a.split('/').last
        
        if i>=0
          is_master(user,repo)
           
          
        end
        i=i+1
       
         
    end
end
method_name
