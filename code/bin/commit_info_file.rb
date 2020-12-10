require 'time'
require 'linguist'
require 'thread'
require 'rugged'
require 'json'
require 'fileutils'
require 'open-uri'
require 'net/http'
# require 'activerecord-import'
require 'active_record'

require File.expand_path('../../lib/all_repo_data_virtual_prior_merge.rb',__FILE__)
require File.expand_path('../../lib/commit_info.rb',__FILE__)

require File.expand_path('../parse_html.rb',__FILE__)
class Commit_file < ActiveRecord::Base
    establish_connection(
        adapter:  "mysql2",
        host:     "10.141.221.85",
        username: "root",
        password: "root",
        database: "cll_data",
        encoding: "utf8mb4",
        collation: "utf8mb4_bin",
        pool: 300
    )
end




module ModuleName
    @thread_num=50
    Commit_info.where("id>0").find_each do |item|
        if item.commit_parents.size>2
            p item.id
        end
    end
    def self.init_commit
        @inqueue = SizedQueue.new(@thread_num)
        threads=[]
                @thread_num.times do 
                thread = Thread.new do
                    loop do
                    commit_hash = @inqueue.deq
                    break if commit_hash == :END_OF_WORK
                    file_name_list=[]
                    commit_parents_list=[]
                    c = ParseHtml.github_commit(@user, @repo, commit_hash,0)
                    unless c.empty? || c.nil?
                        for info in c['files']
                            file_name_list << info['filename']
    
                        end
                        for info in c['parents']
                            commit_parents_list << info['sha']
                        end
                        commit_info=Commit_info.new
                        commit_info.repo_name=@user+"@"+@repo
                        commit_info.message=c['commit']['message']
                        commit_info.commit=commit_hash
                        commit_info.commit_parents=commit_parents_list
                        commit_info.committer_email=c['commit']['committer']['email']
                        commit_info.commit_file=file_name_list
                        commit_info.commit_date=c['commit']['committer']['date']
                        commit_info.save
                    else
                   
                    puts "API-GITHUB 获取失败"
                   
                    #需要删掉build?
                    end
                    
                    end
                end
                    threads << thread
                end
                threads       
    end
    def self.insert_commit(user,repo)
        Thread.abort_on_exception = true
        @user=user
        @repo=repo
        threads = init_commit
        commit_list=[]
        commit_info_list=[]
        All_repo_data_virtual_prior_merge.where("repo_name=?","#{user}@#{repo}").find_each do |item|
            for commit in item.commit_list
                commit_list << commit
            end
            
        end
        commit_list.uniq!
        p commit_list.size
        Commit_info.select("commit").where("repo_name=?","#{user}@#{repo}").find_all do |item|
            
            commit_info_list <<item.commit
        end
        commit_info_list.uniq!
        p commit_info_list.size
        left_list=commit_list-commit_info_list
        p "left===#{left_list.size}"
        for item in left_list
         @inqueue.enq item
        end
             
        @thread_num.times do   
        @inqueue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "Update Over"
        
    end
    
end

ModuleName


