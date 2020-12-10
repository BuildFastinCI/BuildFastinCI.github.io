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
require File.expand_path('../../lib/travis_torrent.rb',__FILE__)
require File.expand_path('../../lib/within_filepath.rb',__FILE__)
require File.expand_path('../../lib/pre_pass.rb',__FILE__)
require File.expand_path('../../lib/tmp_prevpassed.rb',__FILE__)

require File.expand_path('../parse_html.rb',__FILE__)
#require File.expand_path('../../fix_sql.rb',__FILE__)
@user=ARGV[0]
@repo=ARGV[1]
@out_queue = SizedQueue.new(2000)
$token = [
  "3f5cd6ea063da76429c2ac7616bb4061fe94477b",#我
  "eecd9fbfe794668811c673f252fc96a01f4e378f",#小白
  "047a47a4f6cf125e4ef9f095c5afa6419b4bc292",#xue
  "7d796d2bfca8ab9766dea7d0a4bcf5987609a391",#学弟
  "dc6fa8c5a0fd1c513f13ed1e23d3323ff21fc616",
  "0301031709c2b4ecfea9b9cd2751a38da83e6676",#wo
]
$REQ_LIMIT = 4990
$text_file=["md","doc","docx","txt","csv","json","xlsx","xls","pdf","jpg","ico","png","jpeg","ppt","pptx","tiff","swf"]
$thread_number=40
module DiffWithin
    

  include JavaData
  def self.test_diff(user,repo,last_pass,record,lef)
    #small_test=Small_test.new
    @user=user
    @repo=repo
    
    #repos = Rugged::Repository.new("repos/#{user}/#{repo}")
    #repo = Rugged::Repository.new("git_travis_torrent/repos/threerings/tripleplay")
    #builds.map do|build|
    #File.expand_path(File.join('..', '..', '..', 'sequence', 'repository',user+'@'+'repo1'), File.dirname(__FILE__))
    
    checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository', user+'@'+ repo),File.dirname(__FILE__)) 
    #checkout_dir = File.expand_path(File.join('..', '..', '..', 'sequence', 'repository',user+'@'+'repo1'), File.dirname(__FILE__))
    
    #puts checkout_dir
    flag = File::exists?("README.md")
    
    # begin
    #   repo = Rugged::Repository.new(checkout_dir)
    #   unless repo.bare?
    #     puts "not bare"
    #     spawn("cd #{checkout_dir} && git pull")
    #   end
    #   repo
    #   puts repo.path
      
    # rescue
    #   spawn("git clone git://github.com/#{user}/#{repo}.git #{checkout_dir}")
    # end
     
    filepath={}
    build_compare=[]
    Thread.abort_on_exception = true
    threads = init_diff_start
    repo_name="#{user}/#{repo}"
    if lef==0
      Withinproject.where("id>0 and gh_project_name=?",repo_name).group('git_commit').find_each do |build|
        #build[:repo_name]="#{user}@#{repo}"
        
          @queue.enq [build,user,repo,checkout_dir,0,lef]
        
      end
    else
      #Withinproject.where("id>0 and gh_project_name=?",repo_name).find_each do |build|
        #build[:repo_name]="#{user}@#{repo}"
        for lastpass in last_pass do
          # begin
            
          @queue.enq [record,user,repo,checkout_dir,lastpass,lef]
        end
      
    end
    $thread_number.times do   
    @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "DiffUpdate Over"
  
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
            repos = Rugged::Repository.new(info[3])
          end
          #puts repos
          break if info == :END_OF_WORK
          begin
            
            if info[4]!='0'#last_commit
              
              from = repos.lookup(build)
              to = repos.lookup(info[4])
              
            else
              from = repos.lookup(build.git_commit)
              to = repos.lookup(build.pre_builtcommit)
              
            end
            diff = to.diff(from)
          #puts diff.patch
          test_added = test_deleted = 0
          test_num=src_num=txt_num=config_num=0
          src_arry=[]
          state = :none
          #arry= diff.stat#number of filesmodified/added/delete
          
          
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
              #puts file_name
              #file_dir = File.dirname(file_path)#路径/可以用来判断是否是test文件
              next if file_path.nil?
              
              
              flag=0
            end
      
            
          end
          #puts build[:build_id]
          if info[5]==0
            acc={:repo_name=>build.gh_project_name,:tr_build_id=>build.tr_build_id,:prev_builtcommit=>build.pre_builtcommit,:filpath=>temp_filepath}
            filepaths=Within_filepath.new(acc)
            filepaths.save
          else
            acc={:repo_name=>@user+'/'+@repo,:git_commit=>build,:prev_passcommit=>info[4],:filpath=>temp_filepath}
            filepaths=Prev_passed.new(acc)
            #filepaths=Tmp_passed.new(acc)
            filepaths.save
            #ActiveRecord::Base.clear_active_connections!
          end
          
          
          rescue
            #处理需要远程话获取diff信息的compare
            puts "处理需要远程话获取diff信息的compare"
            #build_compare << build[:now_build_commit]
            if info[4]!=0
              c=git_compare(build,info[4],info[1],info[2],rand(0..7))
            else
              c=git_compare(build.git_commit,build.pre_builtcommit,info[1],info[2],rand(0..7))
            end
            
            unless c.empty?
              puts "处理diff"
              if info[5]!=0
                diff_compare(c,build,info[5])
              else
                diff_compare(c,build,0)
              end
              
            end
            next
            
          end
          #puts "loacal========"
          
          #ActiveRecord::Base.clear_active_connections!
          
          
          #ActiveRecord::Base.clear_active_connections!
        end
      end
      threads << thread
    end
  
  threads
  end


  def self.git_compare(now,last,owner,repo,num)
    parent_dir = File.join('compare', "#{owner}@#{repo}")
    commit_json = File.join(parent_dir, "#{last[0,7]}@#{now[0,7]}.json")
    FileUtils::mkdir_p(parent_dir)

    r = {}
    
  if File.exists? commit_json
      r= begin
        JSON.parse File.open(commit_json).read
    rescue
      {}
    
    end
  end
  unless r.empty?
    return r
  end
  if r.empty? ||  !(File.exists? commit_json)
  
    unless r.nil? || r.empty?
        return r
      
    else
    

    url = "https://api.github.com/repos/#{owner}/#{repo}/compare/#{last}...#{now}"
    puts "Requesting #{url} (#{@remaining} remaining)"

    contents = nil
    begin
      puts "begin"
      
      r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{$token[num]}")
      
      @remaining = r.meta['x-ratelimit-remaining'].to_i
      puts "@remaining"
      puts @remaining
      @reset = r.meta['x-ratelimit-reset'].to_i
      contents = r.read
      JSON.parse contents
    rescue OpenURI::HTTPError => e
      @remaining = e.io.meta['x-ratelimit-remaining'].to_i
      @reset = e.io.meta['x-ratelimit-reset'].to_i
      puts  "Cannot get #{url}. Error #{e.io.status[0].to_i}"
      puts @remaining
      puts $token[num]
      {}
    rescue StandardError => e
      puts "Cannot get #{url}. General error: #{e.message}"
      puts $token[num]
      {}
    ensure
      File.open(commit_json, 'w') do |f|
        f.write contents unless r.nil?
        if r.nil? and 5000 - @remaining >= 6
          puts "xxxxx"
          git_compare(now, last, owner,repo,rand(0..7))
        end
        
      
      end

      if 5000 - @remaining >= $REQ_LIMIT
        to_sleep = 500
        puts $token[num]
        puts "Request limit reached, sleeping for #{to_sleep} secs"
        if num!=7
          num+=1
        else
          num=0
        end
        git_compare(now, last, owner,repo,num)
        #sleep(to_sleep)
      end
    end
  end
end
end 


def self.diff_compare(compare_json,build,flag)
  test_added = test_deleted = 0
  test_num=src_num=txt_num=config_num=0
  src_arry=[]
  state = :none
  #number of filesmodified/added/delete
  
  line_added=0
  line_deleted=0
  
  temp_filepath=[]
      
  for info in compare_json['files']
    line_added+=info['additions']
    line_deleted+=info['deletions']
    temp_filepath<< info['filename']
    
    end
  
    
  #parse_html=ParseHtml.new
  
  
  if flag==0
  
    acc={:repo_name=>build.gh_project_name,:tr_build_id=>build.tr_build_id,:prev_builtcommit=>build.pre_builtcommit,:filpath=>temp_filepath}
    filepaths=Within_filepath.new(acc)
    filepaths.save
  else
    acc={:repo_name=>@user+'/'+@repo,:git_commit=>build,:prev_passcommit=>info[4],:filpath=>temp_filepath}
    filepaths=Prev_passed.new(acc)
    #filepaths=Tmp_passed.new(acc)
    filepaths.save
    #ActiveRecord::Base.clear_active_connections!
  end

end


def self.fix_filpath(user,repo)
  puts "hree"
  tr_build_id=[]
  Within_filepath.where("id>0 and filpath is null").find_each do |build|
    tr_build_id=build.tr_build_id
  
  
    
    Withinproject.where("tr_build_id=? and id>0",tr_build_id).find_each do |info|
      puts info
    c=git_compare(info.git_commit,info.pre_builtcommit,user,repo,rand(0..7))
            unless c.empty?
              puts "处理diff"
              diff_compare(c,build,1)
            end
    end
  end
    
end

end
user=ARGV[0]
repo=ARGV[1]
#DiffWithin.test_diff(user,repo)
#DiffWithin.fix_filpath(user,repo)