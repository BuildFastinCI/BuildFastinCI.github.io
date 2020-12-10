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
module DiffTest
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
    @user=user
    @repo=repo
    Thread.abort_on_exception = true
    threads = init_diff_start
    info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
    first_id=info.now_build_id
    last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
    last_id=last_info.now_build_id
    # All_repo_data_virtual_prior_merge.where("repo_name=? and now_build_id<=? and now_build_id>=?","#{@user}@#{@repo}",last_id,first_id).find_each do |info|   
      
    #       @queue.enq [info,@user,@repo,0,0]
       
    # end
    
    info={:now_build_commit=>'f5c2647ff5a46ac34a4a3804385ac96afb80b62d',:last_build_commit=>'2de3a26cdf3d832c610db7c9fa59ed6e195e90e9'}
    @queue.enq [info,@user,@repo,0,0]
    $thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "DiffUpdate Over"
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
          
          end
          diff = to.diff(from)
        #puts diff.patch
        test_added = test_deleted = 0
        test_num=src_num=txt_num=config_num=0
        src_arry=[]
        import_num=0
        flag=0
        #number of filesmodified/added/delete
        
        #记录一下两次build修改的文件,key:build_id,value:[filepath]
       
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
                  
                end
                
                file_name = File.basename(file_path)#文件名
                #puts file_name
                #file_dir = File.dirname(file_path)#路径/可以用来判断是否是test文件
                next if file_path.nil?
          
                if (line.start_with? '-import' or line.start_with? '+import') and JavaData::src_file_filter.call(file_path)
                    import_num+=1
                    
                end
                flag=0
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
                  
                  
                end
                
                #puts file_path
                file_name = File.basename(file_path)#文件名
                #puts file_name
                #file_dir = File.dirname(file_path)#路径/可以用来判断是否是test文件
                next if file_path.nil?
    
                if line.start_with? '+import' 
                        import_num+=1
                end
            end
  
    
          
        end
        puts "import_num:======#{import_num}"
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

      
          puts "==============add+to all_reppo_merge"
        #   build.cmt_importchangecount=import_num
        #   build.save
          
        else

          
          
        end
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
            git_compare(now, last, owner,repo)
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



def self.diff_compare(compare_json,build=0,flag,lef)
  test_added = test_deleted = 0
  test_num=src_num=txt_num=config_num=0
  src_arry=[]
  state = :none
  #number of filesmodified/added/delete
  
  import_num=0
  
  
    
  #parse_html=ParseHtml.new
  diff=ParseHtml.download_diff(compare_json['diff_url'])
 
  i=0
  diff.lines do |line|
    
  
       
    if line.start_with? '+++' and flag==1
        file_path = line.strip.split('+++ ')[1]
        
        if file_path.nil?
          
         
         next
        end
        if file_path.strip.split('b/',2)[1].nil?
          flag=0
          next
        else
          
          
        end
        
        #puts file_path
        file_name = File.basename(file_path)#文件名
        #puts file_name
        #file_dir = File.dirname(file_path)#路径/可以用来判断是否是test文件
        next if file_path.nil?

        if line.start_with? '+import' 
                import_num+=1
        end
    end
    
  end
  puts "=======import_num: #{import_num}"
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
    
    # build.cmt_importchangecount=import_num
    # build.save
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
# DiffTest.test_diff("structr","structr")