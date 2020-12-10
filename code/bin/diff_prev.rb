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
require File.expand_path('../../lib/cll_prevpass.rb',__FILE__)


require File.expand_path('../parse_html.rb',__FILE__)
#require File.expand_path('../../fix_sql.rb',__FILE__)



$REQ_LIMIT = 4990
$text_file=["md","doc","docx","txt","csv","json","xlsx","xls","pdf","jpg","ico","png","jpeg","ppt","pptx","tiff","swf"]
$thread_num=20
module DiffPrev
  @token = [
    # "623f6c239d614b0c12ed94642815efe39a69d59b",#bad
    "e7ee74749713821a882af6955212ca5926df2889",#bad
    "1e2e6a896a4f081f6cbf8e99003980d36a01153f",#xue
    # "4d37d731bc445de2421f4fbe7bf8ff772ce9af0b",
    "38dbc6ce08b536f86b226afa533e8198f03ccf11",
    "43d40a4f7e730416d7642b727c75674e7b39241b",
    "fbc83d122891cb443b1c5c02cdfd491cd6d8e042"
   
  ]
    def self.test_diff(user,repo,last_pass,now_build,lef,type)
        @user=user
        @repo=repo
        @last_pass=last_pass
        checkout_dir =File.expand_path(File.join('..','..','..','sequence', 'repository', user+'@'+ repo),File.dirname(__FILE__)) 
        for lastpass in last_pass do
            
            # if Cll_prevpassed.where("git_commit=? and prev_passcommit=?",now_build,lastpass).count>0
            #   next
            # else
              do_diff(now_build,user,repo,checkout_dir,lastpass,lef,type)
            # end
        end
    
    end

    def self.do_diff(now_build,user,repo,checkout_dir,lastpass,lef,type)
        begin
            from = repos.lookup(now_build)
            to = repos.lookup(lastpass)
            
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
            if type=='cll'
                today = Time.new
                acc={:repo_name=>@user+'@'+@repo,:git_commit=>now_build,:prev_passcommit=>lastpass,:filpath=>temp_filepath,:insert_time=>today.strftime("%Y-%m-%d %H:%M:%S")}
                filepaths=Cll_prevpassed.new(acc)
                filepaths.save
            end
            if type=='within'
                acc={:repo_name=>@user+'/'+@repo,:git_commit=>now_build,:prev_passcommit=>lastpass,:filpath=>temp_filepath}
                filepaths=Prev_passed.new(acc)
                #filepaths=Tmp_passed.new(acc)
                filepaths.save
                ActiveRecord::Base.clear_active_connections!
            end
            
        rescue => exception
          i=0
           if i>=0
            k=i % (@token.size)
            i=i+1
            c=git_compare(now_build,lastpass,user,repo,k)
            unless c.empty?
                
                if lef!=0
                  puts "处理diff"
                  diff_compare(c,now_build,lastpass,lef,type)
                 
                # else
                #   diff_compare(c,build,0)
                end
                
            end
          end
        end
            
        
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
        puts"#{@remaining} remaining"
    
        contents = nil
        begin
          puts "begin"
          
          r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{@token[num]}")
          
          @remaining = r.meta['x-ratelimit-remaining'].to_i
          puts "@remaining"
          puts "Requesting #{url} (#{@remaining} remaining)"
          @reset = r.meta['x-ratelimit-reset'].to_i
          contents = r.read
          JSON.parse contents
        rescue OpenURI::HTTPError => e
          @remaining = e.io.meta['x-ratelimit-remaining'].to_i
          @reset = e.io.meta['x-ratelimit-reset'].to_i
          puts  "Cannot get #{url}. Error #{e.io.status[0].to_i}"
          puts "#{@remaining }===#{@token[num]} "
          
          {}
        rescue StandardError => e
          puts "Cannot get #{url}. General error: #{e.message}"
          puts @token[num]
          {}
        ensure
          File.open(commit_json, 'w') do |f|
            f.write contents unless r.nil?
            f.write '' if r.nil?
            
          
          end
    
          if 5000 - @remaining >= $REQ_LIMIT
            to_sleep = 500
            puts @token[num]
            puts "Request limit reached, sleeping for #{to_sleep} secs"
            if num!=@token.size-1
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
    
    
    def self.diff_compare(compare_json,build,lastpass=0,flag,type)
      
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
      
      
      if type=='cll'
        today=Time.new
        acc={:repo_name=>@user+'@'+@repo,:git_commit=>build,:prev_passcommit=>lastpass,:filpath=>temp_filepath,:insert_time=>today.strftime("%Y-%m-%d %H:%M:%S")}
        filepaths=Cll_prevpassed.new(acc)
        filepaths.save
      
      else
        acc={:repo_name=>@user+'/'+@repo,:git_commit=>build,:prev_passcommit=>lastpass,:filpath=>temp_filepath}
        filepaths=Prev_passed.new(acc)
        #filepaths=Tmp_passed.new(acc)
        filepaths.save
        ActiveRecord::Base.clear_active_connections!
      end
    
    end
    
    
end

# @token = [
#   # "623f6c239d614b0c12ed94642815efe39a69d59b",#bad
#   "e7ee74749713821a882af6955212ca5926df2889",#bad
#   "1e2e6a896a4f081f6cbf8e99003980d36a01153f",#xue
#   "4d37d731bc445de2421f4fbe7bf8ff772ce9af0b",
#   "38dbc6ce08b536f86b226afa533e8198f03ccf11",
#   "43d40a4f7e730416d7642b727c75674e7b39241b",
#   "fbc83d122891cb443b1c5c02cdfd491cd6d8e042"
 
# ]
# last='b9ca75e9b26f7337196e33bc5162bdf852b234fc'
# now='00394069d03459b919ee7d0c71075cd7e1f23aac'
# url = "https://api.github.com/repos/jOOQ/jOOQ/compare/#{last}...#{now}"
        
    
# contents = nil
#   p @token.size
#   puts "begin"
#   num=0
#   for m in (0..@token.size) do
#     i=num% @token.size
#     num+=1

#     puts "=====#{i}"
#   r = open(url, 'User-Agent' => 'ghtorrent', 'Authorization' => "token #{@token[i]}")
  
#   @remaining = r.meta['x-ratelimit-remaining'].to_i
#   puts "@remaining"
#   puts "Requesting #{url} (#{@remaining} remaining)"
#   @reset = r.meta['x-ratelimit-reset'].to_i
#   contents = r.read
#   JSON.parse contents
#   end