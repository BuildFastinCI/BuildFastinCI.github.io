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
require File.expand_path('../parse_html.rb',__FILE__)
#require File.expand_path('../../fix_sql.rb',__FILE__)
# @user=ARGV[0]
# @repo=ARGV[1]
@out_queue = SizedQueue.new(2000)
$token = [
  "baeb194686215604af80044f10ef4ffb32c903cb",
              "d50d8c48d4a0e60f8c7201c70368d303c3bdc625",
              "7f11251413da346325b636301bf394efc172f431",
              "623f6c239d614b0c12ed94642815efe39a69d59b",#我
              "e7ee74749713821a882af6955212ca5926df2889",#我2
              # "1e2e6a896a4f081f6cbf8e99003980d36a01153f",#xue
              # "44702440fac7f14adbd57e7cb08084c4dd036c32",#思聪
              # "2a47b42a0135dcb6b3fedaf2f5fb09752521fc96",#国哥
              # "7192bcb7171a87b84fe8cec6303dc851fecbf3cd",#施博文
              "4d37d731bc445de2421f4fbe7bf8ff772ce9af0b",#谢东方
              # "38dbc6ce08b536f86b226afa533e8198f03ccf11",#谢隽丰
              "43d40a4f7e730416d7642b727c75674e7b39241b",#涂轩涵
              "fbc83d122891cb443b1c5c02cdfd491cd6d8e042"#吴帅
]
$REQ_LIMIT = 4990
$text_file=["md","doc","docx","txt","csv","json","xlsx","xls","pdf","jpg","ico","png","jpeg","ppt","pptx","tiff","swf"]
$thread_number=60
$num_data=0
module DiffTest
  
 
  include JavaData
  def self.test_download(user,repo,lastpass,nowcommit,lef)
    builds = load_builds(user, repo,"all_repo_virtual_prior_mergeinfo.json")
    for build in builds
      c=git_compare(build[:now_build_commit],build[:last_build_commit],user,repo)
    end
  end
  
  def self.test_diff(user,repo,lastpass=0,nowcommit=0,lef=0)
    #small_test=Small_test.new
    p "comming in "
    @user=user
    @repo=repo
    if lef==0
      builds = load_builds(@user, @repo,"all_repo_virtual_prior_mergeinfo_father_id.json")
      
      
      # if File_path.where("repo_name=?",builds[0][:repo_name]).count>1
      #   return
        
      # end
      #builds=[{"now_build_commit":"0db6529e47db0d0e5e695d44ea5af26ce836efa7","commit_list":["0db6529e47db0d0e5e695d44ea5af26ce836efa7","80b78c8ba68e32963e1684787a10b7f78c91e81a"],"last_build_commit":"80b78c8ba68e32963e1684787a10b7f78c91e81a","authors":["hugo.van.rijswijk@hva.nl","cpovirk@google.com"],"num_author":2,"id":2278,"repo_name":"google@guava","build_id":"84682282","commit":"0db6529e47db0d0e5e695d44ea5af26ce836efa7","pull_req":2183,"branch":"master","status":"passed","message":"Set release version numbers to 19.0-rc2","duration":3501,"started_at":"2015-10-10T16:57:30Z","jobs":[84682283,84682284,84682285],"event_type":"pull_request","author_email":"cgdecker@google.com","committer_email":"cgdecker@google.com","tr_virtual_merged_into":"80b78c8ba68e32963e1684787a10b7f78c91e81a","merge_commit":"07326071e771c9244123791f00b848cc4f44fd9f","father_id":1}]
      arry=[]

      builds=builds.uniq
      #repos = Rugged::Repository.new("repos/#{user}/#{repo}")
      #repo = Rugged::Repository.new("git_travis_torrent/repos/threerings/tripleplay")
      #builds.map do|build|
      
        
      filepath={}
      build_compare=[]
      Thread.abort_on_exception = true
      threads = init_diff_start
      for build in builds
        build[:repo_name]="#{user}@#{repo}"
        if build.has_key?(:build_id)
          @queue.enq [build,user,repo,nowcommit,lef]
          $num_data+=1
        end
      end
    else#fix_build调用
      builds = fixbuild_load_builds(user, repo,"all_repo_virtual_prior_mergeinfo_father_id.json")
      arry=[]

      builds=builds.uniq
      #repos = Rugged::Repository.new("repos/#{user}/#{repo}")
      #repo = Rugged::Repository.new("git_travis_torrent/repos/threerings/tripleplay")
      #builds.map do|build|
      
        
      filepath={}
      build_compare=[]
      Thread.abort_on_exception = true
      threads = init_diff_start
      for build in builds
        build[:repo_name]="#{user}@#{repo}"
        if build.has_key?(:build_id)
          @queue.enq [build,user,repo,nowcommit,0]
        end
      end
    end
    $thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "DiffUpdate Over"
    return $num_data
    #return
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
          checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository',info[1]+'@'+info[2]),File.dirname(__FILE__)) 
          repos = Rugged::Repository.new(checkout_dir)
        end
        #puts repos
        break if info == :END_OF_WORK
        begin
          if info[4]==0
          from = repos.lookup(build[:now_build_commit])
          to = repos.lookup(build[:last_build_commit])
          else
            from = repos.lookup(info[3])
            to = repos.lookup(info[0])
          end
          diff = to.diff(from)
        #puts diff.patch
        test_added = test_deleted = 0
        test_num=src_num=txt_num=config_num=0
        src_arry=[]
        state = :none
        arry= diff.stat#number of filesmodified/added/delete
        if  info[4]==0
          build[:filesmodified]= arry[0]
          build[:line_added]=arry[1]
          build[:line_deleted]=arry[2]
          build[:error_file_fixed]=0
          build[:src_modified]=0
          if !build.has_key?:tr_virtual_merged_into
            build[:tr_virtual_merged_into]= nil
          end
        end
        #记录一下两次build修改的文件,key:build_id,value:[filepath]
        temp_filepath=[]
        flag=0
        file_added=0
        file_deleted=0
        src_churn=0
        test_churn=0
        config_churn=0
        state = :none
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
              src_arry<< file_path.strip.split('b/',2)[1]
            else 
              state = :config
              config_num+=1
              
            end
            flag=0
          end
          if line.start_with? 'new file mode'
            file_added+=1
            
          end
          if line.start_with? 'deleted file mode'
            file_deleted+=1
            
          end
          
          if line.start_with? '-' 
            
            case state
            when  :in_test
              test_churn+=1
              if JavaData::test_case_filter.call(line)
                test_deleted += 1
                
              end
            when :in_src
              src_churn+=1
              
            when  :config
              config_churn+=1
            else
              
            end
          end
    
          if line.start_with? '+' 
            
            case state
            when  :in_test
              test_churn+=1
              if JavaData::test_case_filter.call(line)
                test_added += 1
                
              end
            when  :in_src
              src_churn+=1
              
            when  :config
              config_churn+=1
            else
              
            end
          end
  
    
          if line.start_with? 'diff --'
            state = :none
          end
        end
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
        if info[4]==0
          today = Time.new

      
          
          file_paths=File_path.new
          file_paths.repo_name=build[:repo_name]
          file_paths.build_id=build[:build_id]
          file_paths.father_id=build[:father_id]
          file_paths.last_build_commit=build[:last_build_commit]
          file_paths.now_build_commit=build[:now_build_commit]
          file_paths.filpath=temp_filepath
          file_paths.src_path=src_arry
          file_paths.insert_time=today.strftime("%Y-%m-%d %H:%M:%S")
          file_paths.save
          
          #ActiveRecord::Base.clear_active_connections!
          
          build.delete(:id)
          build.delete(:jobs_arry)
          build.delete(:jobs_state)
          build[:commit_size]=build[:commit_list].size
          if build[:status]=="passed"
            build[:last_label]=1
          else
            build[:last_label]=0
          end
          if build[:branch]=="master"
            build[:is_master]=1
            
          else
            build[:is_master]=0
          end
          build[:error_file_fixed]=0
    
          build[:file_added]=file_added
          build[:file_deleted]=file_deleted
          build[:insert_time]=today.strftime("%Y-%m-%d %H:%M:%S")
          #build[:txt_file]=txt_file
          acc={:test_file=>test_num,:src_file=>src_num ,:txt_file=>txt_num,:config_file =>config_num,:src_churn=>src_churn,:test_churn=>test_churn}
          build=build.merge(acc)
  #测试不保存
          # c=All_repo_data_virtual_prior_merge.new(build)
          # c.save
          # ActiveRecord::Base.clear_active_connections!
          
          
        else

          acc={:repo_name=>@user+'@'+@repo,:git_commit=>info[3],:prev_passcommit=>info[0],:filpath=>temp_filepath}
          filepaths=Cll_prevpassed.new(acc)
          filepaths.save
          
        end
        rescue
          #处理需要远程话获取diff信息的compare
          #puts "处理需要远程话获取diff信息的compare"
          if info[4]==0
          #build_compare << build[:now_build_commit]
            c=git_compare(build[:now_build_commit],build[:last_build_commit],info[1],info[2],rand($token.size))
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
    
      
  

  def self.run(user,repo) 
    #FixSql.update_fail_build_rate(user,repo)
    
  end

  def lslr(tree, path = '')
      all_files = []
      for f in tree.map { |x| x }
        f[:path] = path + '/' + f[:name]
        if f[:type] == :tree
          begin
            all_files << lslr(git.lookup(f[:oid]), f[:path])
          rescue StandardError => e
            log e
            all_files
          end
        else
          all_files << f
        end
      end
      all_files.flatten
  end
#def files_at_commit(sha, filter = lambda { true })
  

  def src_files(sha)
      files_at_commit(sha, src_file_filter)
  end

  def src_file_filter
      raise Exception.new("Unimplemented")
  end


# def load_builds(owner, repo,filename)
#   f = File.join("git_travis_torrent/build_logs", "#{owner}@#{repo}", filename)
#   unless File.exists? f
#     puts "不能找到"
#   end
  
#   JSON.parse File.open(f).read, :symbolize_names => true#return symbols
# end
  def self.load_builds(owner, repo,filename)
    f = File.join("build_logs", "#{owner}@#{repo}", filename)
    unless File.exists? f
      puts "不能找到"
    end
    
    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
  end
  def self.fixbuild_load_builds(owner, repo,filename)
    f = File.join("fix_build_logs", "#{owner}@#{repo}", filename)
    unless File.exists? f
      puts "不能找到"
    end
    
    JSON.parse File.open(f).read, :symbolize_names => true#return symbols
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
      begin
        #puts "begin"
        
        r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{$token[num]}")
        
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
            git_compare(now, last, owner,repo)
          end
          
        
        end

        # if 5000 - @remaining >= $REQ_LIMIT
        #   to_sleep = 500
        #   puts "$token[num] #{$token[num]}"
        #   puts "Request limit reached, sleeping for #{to_sleep} secs"
          
        #   sleep(to_sleep)
        # end
      end
    end
  end
  end  



def self.diff_compare(compare_json,build=0,flag,lef)
  test_added = test_deleted = 0
  test_num=src_num=txt_num=config_num=0
  src_arry=[]
  state = :none
  #number of filesmodified/added/delete
  
  line_added=0
  line_deleted=0
  file_added=0
  file_deleted=0
  file_modified=0
  temp_filepath=[]
  src_churn=0
  test_churn=0
  config_churn=0 
  state = :none  
  for info in compare_json['files']
    line_added+=info['additions']
    line_deleted+=info['deletions']
    file_added+=1 if info['status']=='added'
    file_deleted+=1 if info['status']=='deleted'
    file_modified+=1 if info['status']=='modified'
    temp_filepath<< info['filename']
    file_name = File.basename(info['filename'])#文件名
      #puts file_name
      #file_dir = File.dirname(file_path)#路径/可以用来判断是否是test文件
      
      
      if JavaData::test_file_filter.call(info['filename'])
        
        test_num+=1
        test_churn+=info['changes']
      elsif $text_file.include? file_name.strip.split('.')[1] 
         
        txt_num+=1 
      elsif JavaData::src_file_filter.call(info['filename'])
        
        src_num+=1
        src_churn+=info['changes']
        src_arry<< info['filename']
      else 
        
        config_num+=1
        config_churn+=info['changes']
        
      end
  end
  
    
  #parse_html=ParseHtml.new
  diff=ParseHtml.download_diff(compare_json['diff_url'])
  i=0
  diff.lines do |line|
    if line.start_with? '+++'
      file_path = line.strip.split('+++')[1]
      next if file_path.nil?
      
      #temp_filepath<<file_path.strip.split('b/',2)[1]
      #puts file_path
      file_name = File.basename(file_path)#文件名
      #puts file_name
      #file_dir = File.dirname(file_path)#路径/可以用来判断是否是test文件
      next if file_path.nil?
      
      if JavaData::test_file_filter.call(file_path)
        state = :in_test
       
      
      elsif $text_file.include? file_name.strip.split('.')[1] 
        state = :in_txt   
        
      elsif JavaData::src_file_filter.call(file_path)
        state = :in_src
        
        
      else 
        state = :config
       
        
      end
        
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
 # puts build[:build_id]
 if flag==0 and lef==0
  
  today = Time.new 
  
  # acc={:tests_added => test_added, :tests_deleted => test_deleted ,:test_file=>test_num, 
  # :src_file=>src_num ,:txt_file=>txt_num,:cofig_file =>config_num,:build_id=>build[:build_id],:last_build_commit=>build[:last_build_commit],
  # :repo_name=>build[:repo_name],:father_id=>build[:father_id],:now_build_commit=>build[:now_build_commit]}
  #  filemodif_insert=Filemodif_info.new(acc)
  #  filemodif_insert.save
  
   #ActiveRecord::Base.clear_active_connections!
  
  #x={build[:build_id]=>{"filpath".to_sym=>temp_filepath,"src_path".to_sym=>src_arry}}
   begin
    
    file_paths=File_path.new
    file_paths.insert_time=today.strftime("%Y-%m-%d %H:%M:%S")
    file_paths.repo_name=build[:repo_name]
    file_paths.build_id=build[:build_id]
    file_paths.father_id=build[:father_id]
    file_paths.last_build_commit=build[:last_build_commit]
    file_paths.now_build_commit=build[:now_build_commit]
    file_paths.filpath=temp_filepath
    file_paths.src_path=src_arry
  #测试不保存
    # file_paths.save
     
   rescue => exception
     
   end
    begin
      build.delete(:id)
      build.delete(:jobs_arry)
      build.delete(:jobs_state)
      build[:commit_size]=build[:commit_list].size
    if build[:status]=="passed"
      build[:last_label]=1
    else
      build[:last_label]=0
    end
    if build[:branch]=="master"
      build[:is_master]=1
      
    else
      build[:is_master]=0
    end
    
    build[:error_file_fixed]=0
    build[:src_modified]=0
    build[:filesmodified]= file_modified
    build[:file_added]=file_added
    build[:file_deleted]=file_deleted
    build[:line_added]=line_added
    build[:line_deleted]=line_deleted
    build[:insert_time]=today.strftime("%Y-%m-%d %H:%M:%S")
    acc={:test_file=>test_num,:src_file=>src_num ,:txt_file=>txt_num,:config_file =>config_num,:src_churn=>src_churn,:test_churn=>test_churn}
    build=build.merge(acc)
#测试不保存
    # c=All_repo_data_virtual_prior_merge.new(build)
    # c.save
    ActiveRecord::Base.clear_active_connections!
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
owner = ARGV[0]
repo = ARGV[1]

#hashnew
#puts Diff_test.instance_methods(false)
starting=Time.now
p DiffTest.test_diff("killbill","killbill")
ending=Time.now
p ending-starting
#Diff_test.run(owner,repo)

#test_diff(owner,repo)
# repos = Rugged::Repository.new("repos/#{owner}/#{repo}")
        
#         from = repos.lookup("5c2b1d082c2753824536c376346d9dc56dc82e5b")
#         to = repos.lookup("d00572edf1c42f9fc9d2419a615588404efd656a")
#         diff = to.diff(from)
#         #puts diff.patch
        
#         arry= diff.stat#number of filesmodified/added/delete
#       puts arry
#        puts  diff.patch
#        #.lines.each do |line|
#        diff = to.diff(from)
#         #puts diff.patch
#         test_added = test_deleted = 0
#         test_num=src_num=txt_num=config_num=0
#         src_arry=[]
#         state = :none
#         arry= diff.stat#number of filesmodified/added/delete
#         build[:filesmodified]= arry[0]
#         build[:line_added]=arry[1]
#         build[:line_deleted]=arry[2]
#         build[:error_file_fixed]=0
#         build[:src_modified]=0
#         if !build.has_key?:tr_virtual_merged_into
#           build[:tr_virtual_merged_into]= nil
#         end
#         #记录一下两次build修改的文件,key:build_id,value:[filepath]
#         temp_filepath=[]
#         flag=0
#         file_added=0
#         file_deleted
#         diff.patch.lines.each do |line|
         