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
#require File.expand_path('../../fix_sql.rb',__FILE__)
# @user=ARGV[0]
# @repo=ARGV[1]
@out_queue = SizedQueue.new(2000)

$REQ_LIMIT = 4990
$text_file=["md","doc","docx","txt","csv","json","xlsx","xls","pdf","jpg","ico","png","jpeg","ppt","pptx","tiff","swf"]
$thread_number=40
module DiffGum
    @token = [
        # "623f6c239d614b0c12ed94642815efe39a69d59b",#bad
        "e7ee74749713821a882af6955212ca5926df2889",#bad
        "1e2e6a896a4f081f6cbf8e99003980d36a01153f",#xue
        # "4d37d731bc445de2421f4fbe7bf8ff772ce9af0b",
        "38dbc6ce08b536f86b226afa533e8198f03ccf11",
        "43d40a4f7e730416d7642b727c75674e7b39241b",
        "fbc83d122891cb443b1c5c02cdfd491cd6d8e042"
       
      ]
    include JavaData
  def self.test_download(user,repo,lastpass,nowcommit,lef)
    builds = load_builds(user, repo,"all_repo_virtual_prior_mergeinfo.json")
    for build in builds
      c=git_compare(build[:now_build_commit],build[:last_build_commit],user,repo)
    end
  end
  
  def self.test_diff(user,repo)
    #small_test=Small_test.new
    p "import gum"
    @user=user
    @repo=repo
    Thread.abort_on_exception = true
    threads = init_diff_start
    info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
    first_id=info.now_build_id
    last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
    last_id=last_info.now_build_id
    All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=? ","#{@user}@#{@repo}",last_id,first_id).find_each do |info|   
      
          @queue.enq [info,@user,@repo,0,0]
       
    end
    
    
    @queue.enq [info,@user,@repo,0,0]
    $thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "DiffUpdate Over"
    #return
      #for build in builds
  end 

 def self.add_delete_import

  
    @queue=SizedQueue.new(@thread_number)
    threads=[]
    @thread_number.times do 
      thread = Thread.new do
        loop do
          item = @queue.deq
          info=item[0]
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

 def  self.init_diff_start
  @queue=SizedQueue.new($thread_number)
  threads=[]
  $thread_number.times do 
    thread = Thread.new do
      loop do
        info= @queue.deq
        if info!=:END_OF_WORK 
          build=info[0]
          checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository',info[1]+'@'+info[2]),File.dirname(__FILE__)) 
          repos = Rugged::Repository.new(checkout_dir)
        end
        #puts repos
        break if info == :END_OF_WORK
        begin
            c=git_compare(build[:now_build_commit],build[:last_build_commit],info[1],info[2],rand(@token.size))
            unless c.empty?
              #puts "处理diff"
              diff_compare(c,build,0,info[4])
            else
              next
            end
        #   if info[4]==0
        #   from = repos.lookup(build[:now_build_commit])
        #   to = repos.lookup(build[:last_build_commit])
          
        #   end
        #   diff = to.diff(from)
        # #puts diff.patch
        # test_added = test_deleted = 0
        # test_num=src_num=txt_num=config_num=0
        # src_arry=[]
        # import_num=0
        # flag=0
        # state=:none
        # #number of filesmodified/added/delete
        
        # #记录一下两次build修改的文件,key:build_id,value:[filepath]
       
        # diff.patch.lines.each do |line|
        #     if line.start_with? 'diff --'
        #         state = :infile
        #     end
            
        #     if line.start_with? '-import' 
        #         case state
        #         when  :infile
        #             line.gsub!('-import',"")
        #             line.gsub!('.*;',"")
        #             line.strip!
        #             import_del_arry << line
                  
        #         end

        #     end
        #     if line.start_with? '+import' 
        #         case state
        #         when  :infile
        #             line.gsub!('+import',"")
        #             line.gsub!(/[*;]/,"")
        #             line.strip!
        #             import_add_arry << line
                  
        #         end

        #     end
            
        #     if state==:infile
        #         repeat_num=0
        #         for tmps in import_add_arry do 
        #             for value in import_del_arry do 
        #                 if (tmps.include?value or value.include?tmp)
        #                     import_del_arry=import_del_arry-[value]
        #                         repeat_num+=1
        #                 end
        #             end
        #         end

        #     end
          
        # end
        


       
        #puts build[:build_id]
        # acc={:repo_name=>build._filepath,:tr_build_id=>build.tr_build_id,:prev_builtcommit=>build.pre_builtcommit,:filpath=>temp_filepath}
        # filepaths=Within_filepath.new(acc)
        # filepaths.save
        '''
        acc={:tests_added => test_added, :tests_deleted => test_deleted ,:test_file=>test_num, 
        :src_file=>src_num ,:txt_file=>txt_num,:cofig_file =>config_num,:build_id=>build[:build_id],:last_build_commit=>build[:last_build_commit],
        :repo_name=>build[:repo_name],:father_id=>build[:father_id],:now_build_commit=>build[:now_build_commit]}
        filemodif_insert=Filemodif_info.new(acc)
        filemodif_insert.save
        '''
        #ActiveRecord::Base.clear_active_connections!
    
        
        #x={build[:build_id]=>{"filpath".to_sym=>temp_filepath,"src_path".to_sym=>src_arry}}
        
        rescue
          #处理需要远程话获取diff信息的compare
          #puts "处理需要远程话获取diff信息的compare"
          if info[4]==0
          #build_compare << build[:now_build_commit]
            c=git_compare(build[:now_build_commit],build[:last_build_commit],info[1],info[2],rand(@token.size))
            unless c.empty?
              #puts "处理diff"
              diff_compare(c,build,0,info[4])
            else
              next
            end
        
          else
            c=git_compare(info[3],info[0],info[1],info[2],rand(0..4))
            unless c.empty?
              puts "处理diff"
              diff_compare(c,0,info[4])
            else
              next
            end
          end
          
          
        end
        #puts "loacal========"
        
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
      #puts "Requesting #{url} (#{@remaining} remaining)"

      contents = nil
      @remaining=20
      begin
        #puts "begin"
        
        r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{@token[num]}")
        
        @remaining = r.meta['x-ratelimit-remaining'].to_i
        #puts "@remaining"
        #puts @remaining
        @reset = r.meta['x-ratelimit-reset'].to_i
        contents = r.read
        JSON.parse contents
      rescue OpenURI::HTTPError => e
        @remaining = e.io.meta['x-ratelimit-remaining'].to_i
        @reset = e.io.meta['x-ratelimit-reset'].to_i
        puts  "Cannot get #{url}. Error #{e.io.status[0].to_i}"
        #puts @remaining
        #puts $token[num]
        {}
      rescue StandardError => e
        puts "Cannot get #{url}. General error: #{e.message}"
        #puts $token[num]
        {}
      ensure
        File.open(commit_json, 'w') do |f|
          f.write contents unless r.nil?
          if r.nil? and 5000 - @remaining >= 6
            #puts "xxxxx"
            git_compare(now, last, owner,repo,rand(@token.size))
          end
          
        
        end

        if 5000 - @remaining >= $REQ_LIMIT
          to_sleep = 500
          puts "@token[num] #{@token[num]}"
          puts "Request limit reached, sleeping for #{to_sleep} secs"
          
          sleep(to_sleep)
        end
      end
    end
  end
  end  



def self.diff_compare(compare_json,build,flag,lef)
  test_added = test_deleted = 0
  test_num=src_num=txt_num=config_num=0
  src_arry=[]
  state = :none
  #number of filesmodified/added/delete

  import_num=0
  result_each_file=[]
  puts build[:id]
  import_add_arry=[]
  import_delete_arry=[]
  import_asterisk_add=[]
  import_asterisk_delete=[]
  for item in compare_json["files"] do
    
    next if item["patch"].nil?
    item["patch"].lines.each do |line|
            if (line.start_with? '-import' or line.start_with? '+import')
              if line.start_with? '-import'
                
                    line.gsub!('-import',"")
                    line.strip!
                    if line.include? '.*;'
                      line.gsub!('.*;',"")
                      import_asterisk_delete << line
                    else
                      import_delete_arry << line
                    end
                    
              else
                    line.gsub!('+import',"")
                    
                    line.strip!
                    if line.include? '.*;'
                        line.gsub!('.*;',"")
                        import_asterisk_add << line
                    else
                        import_add_arry << line
                    end
              end
               

            end
            
            
    end
  end
    # add_num=import_add_arry.size
    # del_num=import_asterisk_arry.size
    # repeat_num=0
    # for tmps in import_add_arry do 
    #     break if import_asterisk_arry.size==0
    #     for value in import_asterisk_arry do 
    #         if (tmps.include?value or value.include?tmps)
    #             import_asterisk_arry=import_asterisk_arry-[value]
    #                 repeat_num+=1
    #             break
    #         end
    #     end
    # end
    # result_each_file << add_num+del_num-repeat_num
    add_num=import_add_arry.size+import_asterisk_add.size
    
    del_num=import_asterisk_delete.size+import_delete_arry.size
    
      
  
  
    
  #parse_html=ParseHtml.new
 
 # puts build[:build_id]
 if flag==0 and lef==0
  
  
  
  
   begin
    p "========build#{build[:id]} "
    # build.cmt_diff_within=result_each_file.sum
    # build.save
    build.add_import=add_num
    build.deleteimport=del_num
    build.save
   rescue => exception
     
   end
    
  elsif flag!=0
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
  elsif flag==0 and lef!=0
    puts "find_prev"
    acc={:repo_name=>@user+'@'+@repo,:git_commit=>compare_json['commits'][0]['sha'],:prev_passcommit=>compare_json['base_commit']['sha'],:filpath=>temp_filepath}
    filepaths=Cll_prevpassed.new(acc)
    filepaths.save
  else

  end



  #ActiveRecord::Base.clear_active_connections!



end



     
  


end
# DiffTest.test_diff("FasterXML","jackson-databind")