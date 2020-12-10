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
require File.expand_path('../../lib/all_repo_data_virtual.rb',__FILE__)
require File.expand_path('../../lib/commit_info.rb',__FILE__)
require File.expand_path('../../lib/build.rb',__FILE__)
require File.expand_path('../../sola/get_modifiedlines.rb',__FILE__)
require File.expand_path('../../lib/repo_data_travis.rb',__FILE__)
require File.expand_path('../../lib/build_number.rb',__FILE__)
class HistoricalConnect
    def initialize(user,repo)
        @user=user
        @repo=repo
        @thread_number = 50
        build_id_arry=[]
        # All_repo_data_virtual.where(" status in ('errored','failed') and repo_name=?","#{@user}@#{@repo}").order("build_id asc").find_each do |item|
        #     build_id_arry << item.build_id
        # end
        # build_id_arry.uniq!
        
        # file_arry=[]
        # now_file=[]
        # @all_file=Hash.new
        # for id in build_id_arry do
        #     File_path.where("build_id=?",id).find_each do |tmp|
        #           @all_file[id]=tmp.filpath
        #     end

        # end
        # puts "all_files=====#{@all_file.size}"
     
    end

    def update_fail_build_rate
        #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
        puts "fail_build_rate=========="
        Thread.abort_on_exception = true
        threads = init_update_fail_build_rate
        All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and fail_ratio_re=0",0,"#{@user}@#{@repo}").find_each do |info|
        
            
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "fail_build_rateUpdate Over=========="
        return 
          # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
          # info.fail_build_rate=format("%.3f",Float(m)/c)
          # info.save
    
      end 
    
      def init_update_fail_build_rate
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
              m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],"#{@user}@#{@repo}").order("started_at desc").limit(5)
              if !m.nil? and !m.first.nil? and !m.last.nil?
                a=m.first.build_id
                b=m.last.build_id
              else
                next

              end
              c=Repo_data_travi.where("build_id<= ? and repo_name=? and build_id>=? and status not in ('passed','canceled')",a,"#{@user}@#{@repo}",b).count
              
              
              if m.count!=0
                puts '===='
                info.fail_ratio_re=format("%.3f",Float(c)/m.count)
                info.save
                
              end
              ActiveRecord::Base.clear_active_connections!
              end
            end
            threads << thread
          end
    
        threads
      end
#=====================

def indexs
  Thread.abort_on_exception = true
  threads = init_indexs
  All_repo_data_virtual_prior_merge.where("id>? and repo_name=? ",0,"#{@user}@#{@repo}").find_each do |info|
      
          
      @queue.enq info
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "fail_build_rateUpdate Over=========="
  return 
  
end

def init_indexs
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
      thread = Thread.new do
      loop do
          info = @queue.deq
          break if info == :END_OF_WORK
          m=Build_number.where("build_id= ? and repo_name=? ",info[:now_build_id],"#{@user}@#{@repo}").first
          if !m.nil? 
              
              info.build_number=m.build_number
              info.save
          else
              next

          end
         
          
          
          ActiveRecord::Base.clear_active_connections!
          end
      end
      threads << thread
      end

  threads

end
#=====================
def guasian
  Thread.abort_on_exception = true
    threads = init_guasian
    All_repo_data_virtual_prior_merge.where("id>? and repo_name=? ",0 ,"#{@user}@#{@repo}").find_each do |info|
        
            
        @queue.enq info
    end
    @thread_number.times do   
    @queue.enq :END_OF_WORK
    end
    threads.each {|t| t.join}
    puts "fail_build_rateUpdate Over=========="
    return 
    
  
end
def init_guasian
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
      thread = Thread.new do
      loop do
          info = @queue.deq
          break if info == :END_OF_WORK
          build_number_arry=[]
          m=Math::sqrt(2*Math::PI)
         
          alp_f=3
          guasian=0
          
          All_repo_data_virtual_prior_merge.where("now_build_id< ? and repo_name=? and status in ('errored','failed')",info[:now_build_id],"#{@user}@#{@repo}").find_all  do|item|
          
          f=info.build_number-item.build_number
          
          n= Float((-f*f))/Float((2*alp_f*alp_f))
          
           x=Math::exp(n)
           
          guasian = guasian+(1/(m*alp_f))*x
          
          
         
          
          end
          info.gaussian=guasian
          info.save
          ActiveRecord::Base.clear_active_connections!
          end
      end
      threads << thread
      end

  threads

end
#=====================
def update_fail_ratio_com_pr
        #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
        puts "fail_ratio_com_pr=========="
        Thread.abort_on_exception = true
        threads = init_update_fail_ratio_com_pr
        All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and fail_ratio_com_pr=0",0,"#{@user}@#{@repo}").find_each do |info|
        
            
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "fail_build_rateUpdate Over=========="
        return 
          # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
          # info.fail_build_rate=format("%.3f",Float(m)/c)
          # info.save
    
      end 
    
      def init_update_fail_ratio_com_pr
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
            #   m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:now_build_id],"#{@user}@#{@repo}").order("started_at desc")
            #   a=m.first.build_id
            #   b=m.last.build_id
              item=All_repo_data_virtual.where("build_id=?",info[:now_build_id]).first
              m=Repo_data_travi.where("build_id<? and repo_name=? and committer_email=?",info[:now_build_id],"#{@user}@#{@repo}",item.committer_email).count
              c=Repo_data_travi.where("build_id<? and repo_name=? and committer_email=? and status in ('errored','failed')",info[:now_build_id],"#{@user}@#{@repo}",item.committer_email).count
              
              
              if m!=0
                puts "===="
                info.fail_ratio_com_pr=format("%.3f",Float(c)/m)
                info.save
                
              end
              ActiveRecord::Base.clear_active_connections!
              end
            end
            threads << thread
          end
    
        threads
      end
    
#===================
def update_commiter_exp
  #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
  puts "fail_ratio_com_pr=========="
  Thread.abort_on_exception = true
  threads = init_update_commiter_exp
  All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and commiter_exp is null",0,"#{@user}@#{@repo}").find_each do |info|
  
      
      @queue.enq info
  end
  @thread_number.times do   
  @queue.enq :END_OF_WORK
  end
  threads.each {|t| t.join}
  puts "fail_build_rateUpdate Over=========="
  return 
    # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
    # info.fail_build_rate=format("%.3f",Float(m)/c)
    # info.save

end 

def init_update_commiter_exp
  @queue=SizedQueue.new(@thread_number)
  threads=[]
  @thread_number.times do 
    thread = Thread.new do
      loop do
        info = @queue.deq
        break if info == :END_OF_WORK
      #   m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:now_build_id],"#{@user}@#{@repo}").order("started_at desc")
      #   a=m.first.build_id
      #   b=m.last.build_id
        item=All_repo_data_virtual.where("build_id=?",info[:now_build_id]).first
        m=Repo_data_travi.where("build_id<? and repo_name=? and committer_email=?",info[:now_build_id],"#{@user}@#{@repo}",item.committer_email).count
        # c=Repo_data_travi.where("build_id<? and repo_name=? and committer_email=? and status in ('errored','failed')",info[:now_build_id],"#{@user}@#{@repo}",item.committer_email).count
        
        
        
          
        if m!=0
          info.commiter_exp=Math::log(m)
          p Math::log(m)
        else
          info.commiter_exp=-1
          
        end 
        info.save
        ActiveRecord::Base.clear_active_connections!
        end
      end
      threads << thread
    end

  threads
end

#===================
      def update_fail_ratio_com_re
        #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
        puts "fail_ratio_com_re=========="
        Thread.abort_on_exception = true
        threads = init_fail_ratio_com_re
        All_repo_data_virtual_prior_merge.where("id>? and repo_name=? and fail_ratio_com_re=0",0,"#{@user}@#{@repo}").find_each do |info|
        
            
            @queue.enq info
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "fail_ratio_com_re Update Over=========="
        return 
          # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
          # info.fail_build_rate=format("%.3f",Float(m)/c)
          # info.save
    
      end 
    
      def init_fail_ratio_com_re
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
            #   puts info[:now_build_id]
              item=All_repo_data_virtual.where("build_id=?",info[:now_build_id]).first
              m=Repo_data_travi.where("build_id< ? and repo_name=? and committer_email=? ",info[:now_build_id],"#{@user}@#{@repo}",item.committer_email).order("build_id desc").limit(5)
              
              if !m.nil? and !m.first.nil? and !m.last.nil?
                a=m.first.build_id
                b=m.last.build_id
              else
                next

              end
              
              c=Repo_data_travi.where("build_id<=? and build_id>=? and repo_name=? and committer_email=? and status in ('errored','failed')",a,b,"#{@user}@#{@repo}",item.committer_email).order("started_at desc")
              
              
              if m.count!=0
                puts "===="
                info.fail_ratio_com_re=format("%.3f",Float(c.count)/m.count)
                info.save
                
              end
              ActiveRecord::Base.clear_active_connections!
              end
            end
            threads << thread
          end
    
        threads
      end



      def update_file_fail_prob_max
        #c=Repo_data_travi.where( :repo_name => "#{user}@#{repo}").count
        puts "update_file_fail_prob_maxe=========="
        Thread.abort_on_exception = true
        threads = init_file_fail_prob_max
        info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").first
        first_id=info.now_build_id
        # p first_id
        last_info=All_repo_data_virtual_prior_merge.where("repo_name=? and gh_team_size is not null","#{@user}@#{@repo}").order("now_build_id asc").last
        
        last_id=last_info.now_build_id
        # p last_id
    # All_repo_data_virtual_prior_merge.where("  now_build_id >=? and now_build_id<=? and repo_name=? and test_density is null and assert_density is null ",first_id,last_id,"#{@user}@#{@repo}").find_all do |info|
        All_repo_data_virtual_prior_merge.where("now_build_id >=? and now_build_id<=? and repo_name=? and file_fail_prob_max=0",first_id,last_id,"#{@user}@#{@repo}").find_each do |info|    
            @queue.enq info
            
        end
        @thread_number.times do   
        @queue.enq :END_OF_WORK
        end
        threads.each {|t| t.join}
        puts "fail_build_rateUpdate Over=========="
        return 
          # m=Repo_data_travi.where("build_id< ? and repo_name=? ",info[:build_id],reponame).find_each.size
          # info.fail_build_rate=format("%.3f",Float(m)/c)
          # info.save
    
      end 
    
      def init_file_fail_prob_max
        @queue=SizedQueue.new(@thread_number)
        threads=[]
        @thread_number.times do 
          thread = Thread.new do
            loop do
              info = @queue.deq
              break if info == :END_OF_WORK
              build_id_arry=[]
              All_repo_data_virtual.where("build_id<? and status in ('errored','failed') and repo_name=?",info[:now_build_id],"#{@user}@#{@repo}").find_each do |item|
                    build_id_arry << item.build_id
                    
              end
              build_id_arry.uniq!
            #   puts "build_id_arry #{build_id_arry.size}"
              file_arry=[]
              now_file=[]
              File_path.where("build_id=? and repo_name=?",info[:now_build_id],"#{@user}@#{@repo}").find_each do |tmp|
                for filedir in tmp.filpath do 
                    now_file << filedir

                end
              end
             now_file.uniq!
            #  puts "now_file #{now_file.size}"
              # tmp_hash=@all_file.select { |key, value|  build_id_arry.include?key  }
              tmp_hash=@all_file.select { |key, value|  key< info[:now_build_id] }
              file_arry=tmp_hash.values
              modif_num=0
              tmp_hash=Hash.new
              i=0
            #   puts "file_arry.size #{file_arry.size}"
              next if file_arry.size==0
              for file in file_arry do 
                if !now_file.empty? and !file.empty?
            
                    for tmps in file do
                        i=0
                        for value in now_file do
                            i=i+1
                            if tmps!='' and value!=''
                            #puts "value.class:#{value.class}"
                                if tmps.include? value or value.include? tmps
                                    
                                    if !tmp_hash.has_key?(i)
                                        tmp_hash[i]=1
                                        break
                                    else
                                        tmp_hash[i]=tmp_hash[i]+1
                                        break

                                    end
                                    
                                end
                            end
                        end 
                    end
                   
                end

              end
              result=[]
              
                    for i in tmp_hash.values do 
                    result << (Float(i)/file_arry.size).round(4)
                    end
                #  puts [result]
                #  puts file_arry.size
                #  puts info.build_id
                #  puts result.max
                #  puts (result.sum/file_arry.size).round(4)
                #  puts result.sum
                info.file_fail_prob_max=result.max
                info.file_fail_prob_avg=(result.sum/file_arry.size).round(4)
                info.file_fail_prob_sum=result.sum
                info.save
             ActiveRecord::Base.clear_active_connections!
             
              end
            end
            threads << thread
          end
    
        threads
      end
end
m=Repo_data_travi.where("build_id< ? and repo_name=? ",75911379,"structr@structr").order("started_at desc").limit(5)
# m.find_each do |xx|
#     puts xx.build_id
#     puts xx.status
# end

  

