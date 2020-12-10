require 'active_record'
# require 'activerecord-import'
require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../../lib/commit_info.rb',__FILE__)
require File.expand_path('../current_build.rb',__FILE__)



def self.run
  All_repo_data_virtual_prior_merge.where("id > ?", 0).find_each do |build|
    repo_name = build.repo_name
    sha = build.now_build_commit
    author_email = build.committer_email
    ci = Commit_info.find_by(commit: sha)
    next if ci.nil?
    dt = ci.commit_date
    authors_email = []
    Commit_info.where("repo_name = ? AND commit_date < ? AND commit_date >= DATE_SUB(?, INTERVAL 90 DAY)", repo_name, dt, dt).find_each do |tci|
      authors_email << tci.committer_email
    end
    authors_email.uniq!
    flag = authors_email.find_index(author_email).nil? ? false : true
    # p authors_email
    # p author_email
    # p flag
    build.gh_by_core_team_member = flag
    build.save
  end
end

def self.run_team(user,repo)
  @inqueue = SizedQueue.new(@thread_num)
  threads=[]
  @thread_num.times do 
          thread = Thread.new do
              loop do
              build = @inqueue.deq
              break if build == :END_OF_WORK
              repo_name = build.repo_name
              sha = build.now_build_commit
              author_email = build.committer_email
              ci = Commit_info.find_by(commit: sha)
              if !ci.nil?
                dt = ci.commit_date
              else 
                cur=CurrentBuild.new(user,repo)
                c_info=cur.commit_entries(user, repo,sha)
                next if c_info.empty?
                ci=c_info[0]
                dt=ci["date"]
              end
              
              authors_email = []
              Commit_info.where("repo_name = ? AND commit_date < ? AND commit_date >= DATE_SUB(?, INTERVAL 90 DAY)", repo_name, dt, dt).find_each do |tci|
                authors_email << tci.committer_email
              end
              authors_email.uniq!
              flag = authors_email.size
              # p authors_email
              # p author_email
              # p flag
              build.gh_team_size = flag
              build.save
             
              
              
              end
          end
              threads << thread
          end
          threads
end
def self.start_team(user,repo)
      Thread.abort_on_exception = true
        threads = run_team(user,repo)
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        p last_id
        All_repo_data_virtual_prior_merge.where("repo_name=?  and now_build_id<=? and now_build_id>=? and gh_team_size is  null","#{user}@#{repo}",last_id,first_id).find_each do |info|
            
            @inqueue.enq info
        end
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "master Over=========="
        return 
end
def self.method_name
  # parent_dir = File.expand_path('../../new_reponame.txt',__FILE__)
  parent_dir = File.expand_path('../../repo_name.txt',__FILE__)
    repo_name=IO.readlines(parent_dir)
    i=0
    repo_name.each do |line|
        line = JSON.parse(line)
        ActiveRecord::Base.clear_active_connections!
        puts line
        @thread_num=30
        user=line.split('/').first
        repo=line.split('/').last
        
        if i>=0
          start_team(user,repo)
           
          
        end
        i=i+1
       
        

            
    end
end
method_name
