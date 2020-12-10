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


module FixSql
  include JavaData
  # @user = ARGV[0]
  # @repo = ARGV[1]
  # @parent_dir = File.join('build_logs/', "#{@user}@#{@repo}")
  @thread_number = 50
  def self.load_all_builds(rootdir,filename)
      f = File.join(rootdir, filename)
      unless File.exists? f
        puts "不能找到"
      end

      JSON.parse File.open(f).read, :symbolize_names => true#return symbols
  end

  def self.write_file(contents,parent_dir,filename)
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

  def self.fix_virtual_file(parent_dir)
    puts "build"
    builds=[]
    id_arry=[]
    # parent_dir = File.join('build_logs/',  "#{user}@#{repo}")
    File.open(File.join(parent_dir,"test_build_state.json"), "r") do |file|
      file.each_line do |line|
          #puts line()
          #ch=line
          build=JSON.parse(line)
          id_arry=build[:id]
          builds << build
          #puts ch
          #break
      end
    end
  write_file(builds,parent_dir,"build_stats.json")
  return builds
  end



  def fix_all_virtual(user,repo)
      parent_dir = File.join('build_logs/',  "#{user}@#{repo}")
      
      builds = load_all_builds(parent_dir, "all_repo_virtual_prior_mergeinfo.json")
      for build in builds 
          
        all_repo_virtual=All_repo_data_virtual.find_by_commit(build[:commit])
        
        
        unless all_repo_virtual.nil?
          all_repo_virtual.jobs=build[:jobs]
          all_repo_virtual.save
        end
      
      end
  end

  

  def self.insert_into_temp_prior(parent_dir)
    puts 'add father id begin'
    # @parent_dir = File.join('build_logs/', "#{user}@#{repo}")
    builds = load_all_builds(parent_dir, "all_repo_virtual_prior_mergeinfo.json")
    builds.sort!{|x,y| x[:now_build_commit]<=>y[:now_build_commit]}
    for i in (0..builds.size-2)
      builds[i].delete(:id)
      unless builds[i].has_key? :father_id
      builds[i][:father_id]=1
      end
      if builds[i][:now_build_commit]==builds[i+1][:now_build_commit]
        
        builds[i+1][:father_id]=builds[i][:father_id]+1
        builds[i+1].delete(:id)
      else
        builds[i+1][:father_id]=1
        builds[i+1].delete(:id)
      end
    end
    write_file(builds,parent_dir,"all_repo_virtual_prior_mergeinfo_father_id.json")
    # for build in builds
    #   c=Temp_all_virtual_prior_merge.new(build)
    #   c.save
    # end
    return
  end

#====================================================
  def self.init_diff_build_type
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          info = @queue.deq
          break if info == :END_OF_WORK
          jobs_arry=[]
          #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
          repo_path = File.expand_path(File.join('..', '..', '..', 'sequence', 'repository',"#{info.user}@#{info.repo}"), File.dirname(__FILE__))  
          puts repo_path
          begin
            repo = Rugged::Repository.new(repo_path)
            unless repo.bare?
              puts "bare"
              spawn("cd #{repo_path} && git pull")
            end
            repo
            #puts repo.path
            
          rescue
            spawn("git clone git://github.com/#{info.user}/#{info.repo}.git #{repo_path}")
          end
          flag=0
          if File.directory? repo_path
            Dir.foreach(repo_path) do |file|
              #puts file.class
              if file.include? '.gradle'
                info.gradle=1
                info.save
                flag=1
                break
              else
                next
              end
            end
          end
          if flag==0
            info.maven=1
            info.save
          end   
          
        end
        end
        threads << thread
      end

    threads


  end

  def self.diff_build_type#更新load_repo的库用的是maven,gradle还是其他
    Thread.abort_on_exception = true
    threads = init_diff_build_type
    Load_repo.where("id>? and last_id>200",0).find_all do |info|
    
    @queue.enq info
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "Update Over"
  end





#====================================================
  def self.init_update_job_state
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          arry = @queue.deq
          break if arry == :END_OF_WORK
          jobs_arry=[]
          #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
          for job in arry[0].jobs
            job_num=Travis::Job.find(job)
            jobs_arry << job_num.state
          end
  
 
          arry[0].jobs_state=jobs_arry
          arry[0].save
          
          
        end
        end
        threads << thread
      end

    threads
  end
  
  


  def self.update_job_state(user,repo)
    Thread.abort_on_exception = true
    threads = init_update_job_state
    All_repo_data_virtual.where("repo_name=? and jobs_state is null","#{user}@#{repo}").find_all do |info|
    
    @queue.enq [info]
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "Update Over"
  end

#====================================================
def self.init_nowduration
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        arry = @queue.deq
        break if arry == :END_OF_WORK
        # puts arry[0].now_build_id
        # puts arry[0].now_build_id.class
        if !arry[1][arry[0].now_build_id].nil?
          arry[0].now_duration=arry[1][arry[0].now_build_id]
          arry[0].save
        end
        
        
      end
      end
      threads << thread
    end

  threads
end




def self.update_nowduration(user,repo)
  Thread.abort_on_exception = true
  threads = init_nowduration
  h = {}
  All_repo_data_virtual.where("repo_name=?","#{user}@#{repo}").find_all do |item|
    h.store(item.build_id,item.duration)
    
  end
  All_repo_data_virtual_prior_merge.where("repo_name=? and now_duration is null","#{user}@#{repo}").find_all do |info|
  
  @queue.enq [info,h]
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
end
 

#====================================================
def self.upadate_newlabel(user,repo)
  Thread.abort_on_exception = true
  threads = init_upadate_newlabel
  All_repo_data_virtual_prior_merge.where("repo_name=? and new_lastlabel is null","#{user}@#{repo}").find_all do |info|
  
    @queue.enq info
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "newlastlabelUpdate Over"

end

def self.init_upadate_newlabel
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        if info.status == 'errored'
           info.new_lastlabel=0
        elsif info.status == 'failed'
           info.new_lastlabel=-1
        elsif info.status == 'passed'
           info.new_lastlabel=1
        else
        end

        
        info.save
      end
      end
      threads << thread
    end

  threads
end


#=====================================================

  def self.init_update_job_number
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          arry = @queue.deq
          break if arry == :END_OF_WORK
          jobs_arry=[]
          job_state=[]
          #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
          
                
          for job in arry.jobs
            #job_num=nil
            item=Job.where("repo_name=? and job_id=? ",arry.repo_name.gsub('@','/'),job ).first
                # job_num=Travis::Job.find(info.tr_job_id)
                # job_status=job_num.state
                if !item.nil?
                    puts "!item.nil"
                    jobs_arry << item.job_number
                    job_state << item.job_state
                    
                else
                  begin
                    begin
                    job_num=nil
                    job_num=Travis::Job.find(job)
                    #puts "job_num#{job_num.number}"
                    jobs_arry << job_num.number
                    job_state << job_num.state
                    rescue
                      #puts "rescue"
                      #job_num=Travis::Job.find(job)
                      redo if job_num.nil? 
                    end
                    
                  rescue
                    #puts "recue2"
                    redo if job_num.nil? 
                    # job_num=Travis::Job.find(job)
                    # jobs_arry << job_num.number
                    # job_state << job_num.state
                  end

                end
            
          end
  #highest_build = repository.last_build_number.to_i
          redo if jobs_arry.size!=arry.jobs.size
          if jobs_arry.size == arry.jobs.size
            arry.jobs_arry=jobs_arry
            arry.jobs_state=job_state
            arry.save
          end
          
          
          end
        end
        threads << thread
      end
 
    threads
  end


  
  def self.update_job_number(user,repo)
    #for last_status is nill
    Thread.abort_on_exception = true
    #threads = init_update_job_number
    All_repo_data_virtual.where("repo_name=? and  jobs_arry is null and  status in ('errored','failed')","#{user}@#{repo}").find_all do |arry|
    #All_repo_data_virtual.where("repo_name=? and jobs_arry is null and status in ('errored','failed')","#{user}@#{repo}").find_all do |info|
    #All_repo_data_virtual.where("repo_name=? and jobs_arry is not null and status in ('errored','failed')","#{user}@#{repo}").find_all do |info|
    
      if arry.jobs.size!=arry.jobs_arry.size
        puts arry.id
        jobs_arry=[]
        job_state=[]
        #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
        
              
        for job in arry.jobs
          #job_num=nil
          item=Job.where("repo_name=? and job_id=? ",arry.repo_name.gsub('@','/'),job ).first
              # job_num=Travis::Job.find(info.tr_job_id)
              # job_status=job_num.state
              if !item.nil?
                  puts "!item.nil"
                  jobs_arry << item.job_number
                  job_state << item.job_state
                  
              else
                begin
                  begin
                  job_num=nil
                  job_num=Travis::Job.find(job)
                  #puts "job_num#{job_num.number}"
                  jobs_arry << job_num.number
                  job_state << job_num.state
                  rescue
                    puts "rescue"
                    #job_num=Travis::Job.find(job)
                    redo if job_num.nil? 
                  end
                  
                rescue
                  puts "recue2"
                  redo if job_num.nil? 
                  # job_num=Travis::Job.find(job)
                  # jobs_arry << job_num.number
                  # job_state << job_num.state
                end

              end
          
        end
#highest_build = repository.last_build_number.to_i
        redo if jobs_arry.size!=arry.jobs.size
        if jobs_arry.size == arry.jobs.size
          arry.jobs_arry=jobs_arry
          arry.jobs_state=job_state
          arry.save
        end
        
        #@queue.enq info
      end
    end
          # jobs_arry=[]
          # #repository = Travis::Repository.find(arry[0][:repo_name].sub(/@/, "/"))
          # for job in info.jobs
          #   job_num=Travis::Job.find(job)
          #   jobs_arry << job_num.number
          # end

  #highest_build = repository.last_build_number.to_i
          # puts jobs_arry
          
    
    # @thread_number.times do   
    # #@queue.enq :END_OF_WORK
    # end
    # threads.each {|t| t.join}
    puts "job_numberUpdate Over"
    ActiveRecord::Base.clear_active_connections!
    return
  end


#====================================================
  def self.init_update_now_build_status2
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          arry = @queue.deq
          break if arry == :END_OF_WORK
          info=All_repo_data_virtual.find_by_commit(arry[0][:now_build_commit])
          
            #puts arry[0][:now_build_commit]
            unless info.nil?

            arry[0].now_status=info[:status]
            
            end 
            arry[0].save
          if info.nil?
            info=All_repo_data_virtual.find_by_merge_commit(arry[0][:now_build_commit])
            unless info.nil?

              arry[0].now_status=info[:status]
              
              end 
              arry[0].save
          end
          
          end
        end
        threads << thread
      end

    threads
  end


  def self.update_now_build_status2(user,repo)
    #for last_status is nill
    Thread.abort_on_exception = true
    threads = init_update_now_build_status2
    All_repo_data_virtual_prior_merge.where("repo_name=? and now_status is null","#{user}@#{repo}").find_each do |info|
    
    @queue.enq [info]
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "now_statusUpdate Over"
  end
#=================================================================
def self.init_update_now_build_status2
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        arry = @queue.deq
        break if arry == :END_OF_WORK
        info=All_repo_data_virtual.find_by_commit(arry[0][:now_build_commit])
        
          #puts arry[0][:now_build_commit]
          unless info.nil?

          arry[0].now_status=info[:status]
          
          end 
          arry[0].save
        if info.nil?
          info=All_repo_data_virtual.find_by_merge_commit(arry[0][:now_build_commit])
          unless info.nil?

            arry[0].now_status=info[:status]
            
            end 
            arry[0].save
        end
        
        end
      end
      threads << thread
    end

  threads
end


def self.update_now_build_status2(user,repo)
  #for last_status is nill
  Thread.abort_on_exception = true
  threads = init_update_now_build_status2
  All_repo_data_virtual_prior_merge.where("repo_name=? and now_status is null","#{user}@#{repo}").find_each do |info|
  
  @queue.enq [info]
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "now_statusUpdate Over"
end
#====================================================
  def self.init_update_last_build_status#更新now_build_id
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          arry = @queue.deq
          break if arry == :END_OF_WORK
          begin
            info=All_repo_data_virtual.find_by_commit(arry[0][:now_build_commit])
          # puts "commit"
          #   puts arry[0][:now_build_commit]
            if info.nil?
              info=All_repo_data_virtual.find_by_merge_commit(arry[0][:now_build_commit])
            #arry[0].last_status=info[:status]
              arry[0].now_build_id=info[:build_id]
            else
              #arry[0].last_status=info[:status] 
              arry[0].now_build_id=info[:build_id]
            end 
            arry[0].save
          
            
          rescue => exception
            
          end
          
          
          end
        end
        threads << thread
      end

    threads
  end


  def self.update_last_build_status(user,repo)
    Thread.abort_on_exception = true
    threads = init_update_last_build_status
    All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id is null","#{user}@#{repo}").find_each do |info|
    
    @queue.enq [info]
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "now_build_idUpdate Over"
  end
#====================================================
def self.init_update_teamsize#更新last_build_id
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        arry = @queue.deq
        break if arry == :END_OF_WORK
        info=Travistorrent.where("gh_project_name=? and git_commit=?",arry.repo_name.gsub('@','/'),arry.now_build_id).first
        # puts "commit"
        #   puts arry[0][:now_build_commit]
          if !info.nil?
            
          #arry[0].last_status=info[:status]
          puts "travis"
            arry.gh_team_size=info.gh_team_size
            arry.team_flag=1
            arry.save
          else
            
            info=Travistorrent_alldatas.where("gh_project_name=? and git_trigger_commit=?",arry.repo_name.gsub('@','/'),arry.now_build_commit).first
            
            if !info.nil?
              puts "alldatas"
              arry.gh_team_size=info.gh_team_size
              arry.save
              
            else
              info=Travistorrent_822017_alldatas.where("git_trigger_commit=?",arry.now_build_commit).first
              if !info.nil?
                puts "822017"
                arry.gh_team_size=info.gh_team_size
                arry.save
                
              else
                info=Travistorrent_822017_alldatas.where("tr_build_id=?",arry.now_build_id).first
                if !info.nil?
                  puts "822017build_id"
                  arry.gh_team_size=info.gh_team_size
                  arry.save
                else
                  info=Travistorrent_1027_alldatas.where("tr_build_id=?",arry.now_build_id).first
                  if !info.nil?
                    puts "1027build_id"
                    arry.gh_team_size=info.gh_team_size
                    arry.team_flag=1
                    arry.save
                    ActiveRecord::Base.clear_active_connections!
                  end
                end
              end

            end
            
          end 
          
        
        
        end
      end
      threads << thread
    end

  threads
end


def self.update_teamsize(user,repo)
  Thread.abort_on_exception = true
  ActiveRecord::Base.clear_active_connections!
  threads = init_update_teamsize
  info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").first
  first_id=info.now_build_id
  last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{user}@#{repo}").order("now_build_id asc").last
  last_id=last_info.now_build_id
  All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id>=? and now_build_id<=? and now_label is not null and last_label is not null and gh_team_size is null","#{user}@#{repo}",first_id,last_id).find_all do |item|

    @queue.enq info
  end
  
  # All_repo_data_virtual_prior_merge.where("repo_name=? and (gh_team_size is null or gh_team_size=0)","#{user}@#{repo}").find_each do |info|
  
  # @queue.enq info
  # end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "teamsizeUpdate Over"
end

#====================================================
  def self.update_fail_build_rate(user,repo)
    #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
    puts "in here"
    Thread.abort_on_exception = true
    threads = init_update_fail_build_rate
    All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and fail_build_rate=0",0,"#{user}@#{repo}").find_each do |info|
    
    reponame="#{user}@#{repo}"
    @queue.enq [info,reponame]
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "fail_build_rateUpdate Over"
    return 
      # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
      # info.fail_build_rate=format("%.3f",Float(m)/c)
      # info.save

  end 

  def self. init_update_fail_build_rate
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
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

#====================================================
def self.update_now_build_commit
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  puts "in here"
  Thread.abort_on_exception = true
  threads = init_update_now_build_commit
  File_path.where("id>?",0).order("id asc").find_all do |info|  
    puts info  
  @queue.enq info
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 

def self. init_update_now_build_commit
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        Repo_data_travi.where("build_id= ?",info.build_id).find_each do |m|
        info.now_build_commit=m.commit
        info.save
        end
        end
      end
      threads << thread
    end

  threads
end  
#====================================================


#====================================================

def self.update_file_moidfied
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  puts "in here"
  Thread.abort_on_exception = true
  threads = init_update_file_moidfied
  
  Filemodif_info.where("id>?",0).order("id asc").find_each do |info|
  
  @queue.enq info
  end

  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 

def self. init_update_file_moidfied
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        Repo_data_travi.where("build_id=?",info.build_id).find_all do |m|
          
          info.now_build_commit=m.commit
          info.save
        
        end
        ActiveRecord::Base.clear_active_connections!
        end
      end
      threads << thread
    end

  threads
end  



#====================================================
  def fix_jobs(user,repo)
    parent_dir = File.join('build_logs/',  "#{user}@#{repo}")
      
      builds = load_all_builds(parent_dir, "all_repo-data-virtual-builds.json")
      
          
        all_repo_virtual=All_repo_data_virtual.where("jobs=?",'0').find_each do |build_info|
        # a=builds.find{|build| build[:build_id]=='444787259'}
        # puts a
          #puts  build_info[:build_id]
        for build in builds 
          if build[:build_id].to_s == build_info[:build_id]
            puts build[:build_id]
          build_info.jobs=build[:jobs]
          build_info.save
          break
          end
          
        end
        
      
      end
  end

#===================================================
def self.update_now_label(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_update_now_label
  repo_name=user+"@"+repo
  #puts repo_name
  All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and now_label=0",0,repo_name).order("id asc").find_each do |info|
  #puts info
  @queue.enq info
  end

  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "now_labelUpdate Over"
    
end 

def self. init_update_now_label
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        if info.now_status=="passed"
          info.now_label=1
          
        else
          info.now_label=0
        end
        info.save
        ActiveRecord::Base.clear_active_connections!
        end
      end
      threads << thread
    end

  threads
end  

def self.update_last_label(user,repo)
  Thread.abort_on_exception = true
  threads = init_update_last_label
  repo_name=user+"@"+repo
  puts repo_name
  All_repo_data_virtual_prior_merge.where("id>? and repo_name=?",0,repo_name).order("id asc").find_each do |info|
  
  @queue.enq info
  end

  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
  
end

def self.init_update_last_label

  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        if info.status=="passed"
          info.last_label=1
          
        else
          info.last_label=0
        end
        info.save
        #ActiveRecord::Base.clear_active_connections!
        end
      end
      threads << thread
    end

  threads
end
#===================================================
#第一次实现的时候有点问题,已经在源代码修改,下次跑新的程序不需要在这里修复了
  


def self.test_diff(user,repo)
 
  filepath={}
  build_compare=[]
  Thread.abort_on_exception = true
  threads = init_diff_start
  repo_name=user+'@'+repo
  File_path.where("repo_name=?",repo_name).find_each do |info|

  @queue.enq [info,user,repo]
  end
  $thread_number.times do   
  @queue.enq :END_OF_WORK
end
threads.each {|t| t.join}
puts "Update Over"
  #for build in builds
end 
    
def  self.init_diff_start
@queue=SizedQueue.new($thread_number)
threads=[]
$thread_number.times do 
  thread = Thread.new do
    loop do
      info= @queue.deq
      if info!=:END_OF_WORK
        build=info[0]
        repos = Rugged::Repository.new("repos/#{info[1]}/#{info[2]}")
      end
      #puts repos
      break if info == :END_OF_WORK
      begin
      from = repos.lookup(build[:now_build_commit])
      to = repos.lookup(build[:last_build_commit])
      rescue
        #处理需要远程话获取diff信息的compare
        puts "处理需要远程话获取diff信息的compare"
        #build_compare << build[:now_build_commit]
        c=Diff_test.git_compare(build[:now_build_commit],build[:last_build_commit],info[1],info[2],rand(0..3))
        unless c.empty?
          puts "处理diff"
          Diff_test.diff_compare(c,build,1)
        end
        next
        
      end
      #puts "loacal========"
      diff = to.diff(from)
      #puts diff.patch
      test_added = test_deleted = 0
      test_num=src_num=txt_num=config_num=0
      src_arry=[]
      state = :none
      arry= diff.stat#number of filesmodified/added/delete
      
      
      #记录一下两次build修改的文件,key:build_id,value:[filepath]
      temp_filepath=[]
      flag=0
      diff.patch.lines.each do |line|
        if line.start_with? '---' and flag==0
          file_path = line.strip.split('--- ')[1]
          if file_path.nil?
           
           next
          end
          if file_path.strip.split('a/',2)[1].nil?
            flag=1
            next
          else
            temp_filepath<<file_path.strip.split('a/',2)[1]
          end
          
          file_name = File.basename(file_path)#文件名
          #puts file_name
          #file_dir = File.dirname(file_path)#路径/可以用来判断是否是test文件
          next if file_path.nil?
          
          if JavaData::test_file_filter.call(file_path)
            state = :in_test
            test_num+=1
          
          elsif $text_file.include? file_name.strip.split('.')[1] 
            state = :in_txt 
            txt_num+=1 
          elsif JavaData::src_file_filter.call(file_path)
            state = :in_src
            src_num+=1
            src_arry<< file_path.strip.split('a/',2)[1]
          else 
            state = :config
            config_num+=1
            
          end
            
        end
        if line.start_with? '+++' and flag==1
          file_path = line.strip.split('+++ ')[1]
          if file_path.nil?
            
           
           next
          end
          if file_path.strip.split('b/',2)[1].nil?
            flag=0
            next
          else
            temp_filepath<<file_path.strip.split('b/',2)[1]
          end
          
          #puts file_path
          file_name = File.basename(file_path)#文件名
          
          next if file_path.nil?
          
          if JavaData::test_file_filter.call(file_path)
            state = :in_test
            test_num+=1
          
          elsif $text_file.include? file_name.strip.split('.')[1] 
            state = :in_txt 
            txt_num+=1 
          elsif JavaData::src_file_filter.call(file_path)
            state = :in_src
            src_num+=1
            src_arry<< file_path.strip.split('a/',2)[1]
          else 
            state = :config
            config_num+=1
            
          end
          flag=0
        end
  
        if line.start_with? '- ' and state == :in_test
          if JavaData::test_case_filter.call(line)
            test_deleted += 1
          end
        end
  
        if line.start_with? '+ ' and state == :in_test
          if JavaData::test_case_filter.call(line)
            test_added += 1
          end
        end
  
        if line.start_with? 'diff --'
          state = :none
        end
      end
      #puts build[:build_id]
      Filemodif_info.where("last_build_commit=? and now_build_commit=? and father_id=?",build.last_build_commit,build.now_build_commit,build.father_id).find_each do |info|
          info.tests_added=test_added
          info.tests_deleted=test_deleted
          info.test_file=test_num
          info.src_file=src_num
          info.txt_file=txt_num
          info.cofig_file=config_num
          info.save
      end
     
      temp_filepath=temp_filepath.select {|x| !x.nil?}
      build.filpath=temp_filepath
      #file_paths.filpath=temp_filepath
      build.src_path=src_arry
      build.save
    
     
      
      
      
      #ActiveRecord::Base.clear_active_connections!
    end
  end
  threads << thread
end

threads
end
#====================================================
def self.update_errtypeforpass(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  #last_label=1的情况
  Thread.abort_on_exception = true
  threads = init_errtypeforpass
  repo_name=user+"@"+repo
  #puts repo_name
  All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and error_type is null and last_label=1",0,repo_name).order("id asc").find_each do |info|
  #puts info
  @queue.enq info
  end

  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "errtypeforpass Over"
  ActiveRecord::Base.clear_active_connections!
  return 
end 

def self.init_errtypeforpass
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
          info.error_type=4
          
          info.save
        
        end
      end
      threads << thread
    end

  threads
end   
    





#====================================================
def self.update_now_startime(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_update_now_startime
  repo_name=user+"@"+repo
  All_repo_data_virtual_prior_merge.where("repo_name=? and now_start_at is null",repo_name).find_each do |info|
  
  @queue.enq info
  end

  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "now_startimeUpdate Over"
  return
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 

def self. init_update_now_startime
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        
          
        
        unless All_repo_data_virtual.where("commit=?",info.now_build_commit).find_each.size>0
          All_repo_data_virtual.where("merge_commit=?",info.now_build_commit).find_each do |item|
            info.now_start_at=item.started_at
            info.save
          end
        else  
          All_repo_data_virtual.where("commit=?",info.now_build_commit).find_each do |item|
            info.now_start_at=item.started_at
            info.save
          end
        end
        #ActiveRecord::Base.clear_active_connections!
        end
      end
      threads << thread
    end

  threads
end  

#====================================================
def self.update_endtime(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_update_endtime
  repo_name=user+"@"+repo
  puts repo_name
  diff_arry=[]
  All_repo_data_virtual_prior_merge.where("repo_name=? and ended_at is null",repo_name).find_each do |info|
  #puts info
  #diff_arry<<info.duration
    @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "update_endtime Over"
  return 
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_update_endtime
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        Build_number.where("repo_name=? and build_id=?",info.repo_name,info.build_id).find_each do |item|
          info.ended_at=item.ended_at
         
          info.save
        end
        end
      end
      threads << thread
    end

  threads
end  


#====================================================
def self.update_timediff(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  puts "timediffUpdate"
  Thread.abort_on_exception = true
  threads = init_update_timediff
  repo_name=user+"@"+repo
  
  diff_arry=[]
  All_repo_data_virtual_prior_merge.find_by_sql("SELECT id,TIMESTAMPDIFF(MINUTE,all_repo_data_virtual_prior_merges.started_at,all_repo_data_virtual_prior_merges.now_start_at) as duration FROM all_repo_data_virtual_prior_merges where repo_name='#{repo_name}' ").find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "timediffUpdate Over"
  return 
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_update_timediff
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        All_repo_data_virtual_prior_merge.where("id=?",info.id).find_each do |item|
          item.time_diff=info.duration
          item.save
        end
        end
      end
      threads << thread
    end

  threads
end  


#====================================================
def self.update_errornum(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_update_errornum
  repo_name=user+"@"+repo
  puts repo_name
  diff_arry=[]
  File_path.where("modif_num!=0").find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "errornumUpdate Over"
  return 
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_update_errornum
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        All_repo_data_virtual_prior_merge.where("now_build_commit=? and last_build_commit=? and father_id=?",info.now_build_commit,info.last_build_commit,info.father_id).find_each do |item|
          item.modif_num=info.modif_num
          item.error_modified=1
          item.save
        end
        end
      end
      threads << thread
    end

  threads
end  
#====================================================
                    
def self.update_weekday(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_update_weekday
  repo_name=user+"@"+repo
  puts "update_weekday: #{repo_name}"
  diff_arry=[]
  All_repo_data_virtual_prior_merge.where("repo_name=? and week_day is null",repo_name).find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "weekdayUpdate Over"
  return 
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
  
def self.init_update_weekday
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        if !info.now_start_at.nil?
          info.week_day=info.now_start_at.wday
          info.save
        end
        
        end
      end
      threads << thread
    end

  threads
end  

#====================================================
def self.update_bl_cluster(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_update_cluster
  repo_name=user+"@"+repo
  puts "update_bl_cluster#{repo_name}"
  diff_arry=[]
  All_repo_data_virtual_prior_merge.where("repo_name=? and bl_cluster is null",repo_name).find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "clusterUpdate Over"
  return 
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_update_cluster
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        item= Travistorrent.where("git_commit=?",info.last_build_commit).first
        if item.nil?
            item=Travistorrent.where("git_commit=?",info.commit).first
        end
        unless item.nil?
          info.bl_cluster=item.bl_cluster.delete('mvncl').to_i
          
        end
        info.save 
        
        end
      end
      threads << thread
    end

  threads
end  

#===================================================
def self.process_filepath_dup(user,repo)#commit 和 branch都重复
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  ActiveRecord::Base.clear_active_connections!
  Thread.abort_on_exception = true
  threads = init_filepath_dup
  repo_name="#{user}@#{repo}"
  puts repo_name
  diff_arry=[]
  File_path.find_by_sql("SELECT * FROM file_paths where repo_name = '#{repo_name}' group by build_id,now_build_commit,father_id  having count(*)>1 order by build_id asc").find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_filepath_dup #
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        num=File_path.where("build_id=?and now_build_commit=? and father_id=?",info.build_id,info.now_build_commit,info.father_id).count
        File_path.where("build_id=?and now_build_commit=? and father_id=?",info.build_id,info.now_build_commit,info.father_id).order("build_id asc").limit(num-1).destroy_all
        
        end
      end
      threads << thread
    end

  threads
end  
#====================================================


#====================================================
def self.process_dup(user,repo)#commit 和 branch都重复
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_process_dup
  repo_name="#{user}@#{repo}"
  puts repo_name
  diff_arry=[]
  All_repo_data_virtual.find_by_sql("SELECT * FROM all_repo_data_virtuals where repo_name = '#{repo_name}' group by commit,branch  having count(*)>1 order by commit asc").find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_process_dup #
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        num=All_repo_data_virtual.where("commit=?and branch=?",info.commit,info.branch).count
        All_repo_data_virtual.where("commit=?and branch=?",info.commit,info.branch).order("started_at asc").limit(num-1).destroy_all
        
        end
      end
      threads << thread
    end
    
  threads
end  

#====================================================
def self.merge_processdup(user,repo)#now_build_id,commit_size,last_build_commit都重复
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_merge_processdup
  repo_name="#{user}@#{repo}"
  puts repo_name
  diff_arry=[]
  All_repo_data_virtual_prior_merge.find_by_sql("SELECT * FROM all_repo_data_virtual_prior_merges where repo_name = '#{repo_name}' group by now_build_id,commit_size,last_build_commit  having count(*)>1").find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "mergedupUpdate Over"
  return
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_merge_processdup #
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        num=All_repo_data_virtual_prior_merge.where("now_build_id=? and commit_size=? and last_build_commit=?",info.now_build_id,info.commit_size,info.last_build_commit).count
        All_repo_data_virtual_prior_merge.where("now_build_id=? and commit_size=? and last_build_commit=?",info.now_build_id,info.commit_size,info.last_build_commit).limit(num-1).destroy_all
        
        end
      end
      threads << thread
    end

  threads
end  


#====================================================
def self.process_dup2(user,repo)#commit重复全部保留最新的吧
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  
  Thread.abort_on_exception = true
  threads = init_process_dup2
  repo_name="#{user}@#{repo}"
  puts repo_name
  diff_arry=[]
  All_repo_data_virtual.find_by_sql("SELECT * FROM all_repo_data_virtuals where repo_name = '#{repo_name}' group by commit  having count(*)>1 order by commit asc").find_all do |info|
  #puts info
  #diff_arry<<info.duration
  @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_process_dup2 #
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        num=All_repo_data_virtual.where("commit=? ",info.commit).count
        All_repo_data_virtual.where("commit=?",info.commit).order("started_at asc").limit(num-1).destroy_all
        
        end
      end
      threads << thread
    end

  threads
end  
#====================================================
def self.delete_canceled
   
   All_repo_data_virtual_prior_merge.where("status='canceled'").destroy_all
   All_repo_data_virtual_prior_merge.where("now_status='canceled'").destroy_all
   puts "delete_canceled"

end
#===================================================
def self.delete_null(user,repo)
  repo_name="#{user}@#{repo}"
  All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id is null",repo_name).destroy_all
  # All_repo_data_virtual_prior_merge.where("now_status='canceled'").destroy_all
  puts "delete_now_build_id_null"

end
#===================================================
def self.update_srcmodified(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  puts "in here"
  Thread.abort_on_exception = true
  threads = init_updatesrcmodified
  repo_name="#{user}@#{repo}"
  All_repo_data_virtual_prior_merge.select('id','src_modified').where("src_file>0 and repo_name=?",repo_name).find_all do |info|  
    #puts info  
    @queue.enq info
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 

def self. init_updatesrcmodified
  @queue=SizedQueue.new(@thread_number)
  threads=[] 
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        info.src_modified=1
        info.save
        
      end
    end
    threads << thread
  end

  threads
end  


#====================================================

def self.update_commit_size
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  puts "in here"
  Thread.abort_on_exception = true
  threads = init_update_commit_size
  repo_name="#{user}@#{repo}"
  All_repo_data_virtual_prior_merge.where("id>?",repo_name).find_all do |info|  
    #puts info  
    @queue.enq info
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 

def self. init_update_commit_size
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        info.commit_size=info.commit_list.size
        info.save
        
      end
    end
    threads << thread
  end

  threads
end  
#====================================================
def self.update_prevchurn(user,repo)
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  puts "in here"
  Thread.abort_on_exception = true
  threads = init_update_prevchurn
  repo_name="#{user}@#{repo}"
  All_repo_data_virtual_prior_merge.where("repo_name=? and prev_srcchurn=0",repo_name).order("id asc").find_all do |info|  
    puts info.id
  @queue.enq info
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "prevchurnUpdate Over"
   

end 
# def self.init_queue_prevchurn
#   @queue2=SizedQueue.new(@thread_number/2)
#   threads=[]
#   thread = Thread.new do
#     loop do
#       info = @queue2.deq
#       break if info == :END_OF_WORK
#       # puts "typeinfo:#{info}"
#       #   puts  "info.idherer #{info[0]}"
#         info[0].prev_srcchurn=info[1]
#         info[0].prev_testchurn=info[2]
#         info[0].save
       
#     end
#     threads << thread
#   end
#   threads   
# end

def self.init_update_prevchurn
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    # consumer=init_queue_prevchurn
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        prev_srcchurn=0
        prev_testchurn=0
        
        all_repo=All_repo_data_virtual_prior_merge.where("now_build_id=?",info.build_id).first 
        if !all_repo.nil?
          info.prev_srcchurn=all_repo.src_churn
          info.prev_testchurn=all_repo.test_churn
          
          # info.prev_srcchurn=prev_srcchurn
          # info.prev_testchurn=prev_testchurn
          info.save
        end
       
        # info.prev_srcchurn=prev_srcchurn
        # info.prev_testchurn=prev_testchurn
        # info.save
       
      end  
      
    end
    threads << thread
  end
  # @thread_number/2.times do   
  # @queue2.enq :END_OF_WORK
  # end
  # consumer.each {|t| t.join}

  threads
end  

#====================================================

def self.update_type_error(user,repo)
  Thread.abort_on_exception = true
  threads = init_update_type_error
  repo_name=user+"@"+repo
  puts repo_name
  Maven_error.where("id>? and repo_name=?",0,repo_name).order("id asc").find_each do |info|
  
  @queue.enq info
  end

  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
  
end

def self.init_update_type_error

  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        if info.compliation==1
          info.error_type=1
          
        elsif info.test=1
          info.error_type=2
        elsif info.other_error=1
          info.error_type=3
        #ActiveRecord::Base.clear_active_connections!
        else
          info.error_type=0
        end
        info.save
      end
      end
      threads << thread
    end

  threads
end
def self.father_id(user,repo)
  builds=[]
  # @parent_dir = File.join('build_logs/', "#{user}@#{repo}")
  
  #   All_repo_data_virtual.where("repo_name=? ","#{user}@#{repo}").find_each  do |info|
     
  #     builds << info.attributes.deep_symbolize_keys
      
  #   end
  #   write_file(builds,@parent_dir,"no_dupall_repo_data_virtual2.json")
  

  # #builds= load_all_builds(@parent_dir, "no_dupall_repo_data_virtual2.json")
  # global_arry=load_all_builds(@parent_dir, "global_arry.json")
  # filename="all_repo_virtual_prior_mergeinfo.json"
  #    global_arry_copy=global_arry.dup
  #    no_parent_build=[]
  #    global_arry_copy=global_arry_copy.map do |b|
  #    if not ((builds.find { |bs| bs[:commit] == b[:last_build_commit]  }.nil?) and (builds.find { |bs| bs[:merge_commit] == b[:last_build_commit]  }.nil? ))
  #     !builds.find { |bs| bs[:commit] == b[:last_build_commit]  }.nil? ? b=b.merge(builds.find { |bs| bs[:commit] == b[:last_build_commit]}): b=b.merge(builds.find { |bs| bs[:merge_commit] == b[:last_build_commit]})
  #    else
  #       no_parent_build << b[:now_build_commit]
        
  #    end
  #    b
  #    end
  #    global_arry_copy.select!{|m| !no_parent_build.include? m[:now_build_commit]}
  #    global_arry_copy.uniq
  #    write_file(global_arry_copy,@parent_dir,filename)
  #    write_file(no_parent_build,@parent_dir,"no_parent_build.json")
     insert_into_temp_prior(user,repo)#增加father_id

     
     DiffTest.test_diff(user,repo) 
end


#====================================================

  def self.init_week_day
    @queue = SizedQueue.new(@thread_num)
    threads=[]
            @thread_num.times do 
            thread = Thread.new do
                loop do
                info = @queue.deq
                break if info == :END_OF_WORK
                puts info.gh_first_commit_created_at
                puts "weekday：#{info.gh_first_commit_created_at.wday}"
                info.weekday=info.gh_first_commit_created_at.wday
                info.save
                puts "==="
                # puts "========="
                # Withinproject.import builds,validate: false
                ActiveRecord::Base.clear_active_connections!
                end
            end
                threads << thread
            end
    
            threads
    
  end

  def self.weekday(repo_name)
    Thread.abort_on_exception = true
    threads = init_week_day
    puts "here"
    All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and ",0,repo_name).find_each do |info|
        puts info.id
  
        @queue.enq info
    end
    @thread_num.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "weekdayUpdate Over"
    
  end
#====================================================
def self.fixmerge_commit(user,repo)#如果是
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  ActiveRecord::Base.clear_active_connections!
  Thread.abort_on_exception = true
  threads = init_fixmerge_commit
  repo_name="#{user}@#{repo}"
  puts repo_name
  diff_arry=[]
  All_repo_data_virtual_prior_merge.where("repo_name=? and merge_commit is not null",repo_name).find_all do |info|
  #puts info
  #diff_arry<<info.duration
   @queue.enq info
  end
  
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "Update Over"
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 
 
def self.init_fixmerge_commit #
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
        item=All_repo_data_virtual.where("commit=?",info.last_build_commit).order("build_id desc").first
        next if item.nil?
        puts "info.last_build_commit"
        info.duration=item.duration
        if item.status == 'errored'
          info.new_lastlabel=0
          info.last_label=0
       elsif item.status == 'failed'
          info.new_lastlabel=-1
          info.last_label=0
       elsif item.status == 'passed'
          info.new_lastlabel=1
          info.last_label=1
       else
       end
        info.save
        
        end
      end
      threads << thread
    end

  threads
end  
#=====================================================
end
#FixSql.update_job_number("checkstyle","checkstyle")
#checkstyle@checkstyle
    # @user = ARGV[0]
    # @repo = ARGV[1]
       
    #FixSql.update_fail_build_rate(@user,@repo)
    #c.update_fail_build_rate(@user,@repo)
    #update_fail_build_rate(@user,@repo)
    # item=Travis::Job.find('414444336')
    # puts item.number